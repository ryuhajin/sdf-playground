#include <Windows.h>
#include "App.h"

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int nCmdShow) {
    // .exe 실행 위치(더블클릭, 다른 폴더 등)에 무관하게 working directory 를
    // 프로젝트 루트로 고정 — Config.h 의 상대 경로 셰이더/카드 리소스 로드.
    SetCurrentDirectoryA(SDF_SOURCE_ROOT);
    App app;
    return app.Run(hInstance, nCmdShow);
}
