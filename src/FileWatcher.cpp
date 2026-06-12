#include "FileWatcher.h"

FileWatcher::~FileWatcher() { Shutdown(); }

bool FileWatcher::Init(const std::wstring& dir) {
    dir_ = dir;
    handle_ = CreateFileW(dir.c_str(),
        FILE_LIST_DIRECTORY,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        nullptr,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        nullptr);
    if (handle_ == INVALID_HANDLE_VALUE) return false;
    running_ = true;
    thread_ = std::thread([this] { Run(); });
    return true;
}

void FileWatcher::Shutdown() {
    if (!running_) return;
    running_ = false;
    if (handle_ != INVALID_HANDLE_VALUE) {
        CancelIoEx(handle_, nullptr);
    }
    if (thread_.joinable()) thread_.join();
    if (handle_ != INVALID_HANDLE_VALUE) {
        CloseHandle(handle_);
        handle_ = INVALID_HANDLE_VALUE;
    }
}

void FileWatcher::Drain(std::vector<std::wstring>& out) {
    std::lock_guard<std::mutex> g(mu_);
    if (queue_.empty()) return;
    out.insert(out.end(), queue_.begin(), queue_.end());
    queue_.clear();
}

void FileWatcher::Run() {
    BYTE buf[8192];
    while (running_) {
        DWORD bytes = 0;
        BOOL ok = ReadDirectoryChangesW(handle_, buf, sizeof(buf), TRUE,
            FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_FILE_NAME |
            FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_CREATION,
            &bytes, nullptr, nullptr);
        if (!ok || !running_) break;
        if (bytes == 0) continue;

        FILE_NOTIFY_INFORMATION* p = reinterpret_cast<FILE_NOTIFY_INFORMATION*>(buf);
        while (true) {
            std::wstring name(p->FileName, p->FileNameLength / sizeof(WCHAR));
            for (auto& c : name) if (c == L'\\') c = L'/';
            {
                std::lock_guard<std::mutex> g(mu_);
                queue_.push_back(name);
            }
            if (p->NextEntryOffset == 0) break;
            p = reinterpret_cast<FILE_NOTIFY_INFORMATION*>(
                reinterpret_cast<BYTE*>(p) + p->NextEntryOffset);
        }
    }
}
