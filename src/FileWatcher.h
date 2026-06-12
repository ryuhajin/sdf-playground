#pragma once
#include <Windows.h>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class FileWatcher {
public:
    ~FileWatcher();
    bool Init(const std::wstring& dir);
    void Shutdown();
    void Drain(std::vector<std::wstring>& out);

private:
    void Run();

    std::wstring             dir_;
    HANDLE                   handle_ = INVALID_HANDLE_VALUE;
    std::thread              thread_;
    std::atomic<bool>        running_{ false };
    std::mutex               mu_;
    std::vector<std::wstring> queue_;
};
