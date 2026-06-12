#include "Coverflow.h"
#include <algorithm>
#include <cmath>

using namespace DirectX;

namespace {
// |pos| ∈ [0,2+] 에 대해 piecewise interp:
//   |pos| ≤ 1: lerp(0, v_near, |pos|)
//   1 < |pos|: lerp(v_near, v_far, |pos| - 1)
float InterpNearFar(float ax, float v_near, float v_far) {
    if (ax <= 1.0f) return ax * v_near;
    return v_near + (ax - 1.0f) * (v_far - v_near);
}

// 스케일은 |pos|=0 일때 1.0 에서 시작.
float InterpScale(float ax, float v_near, float v_far) {
    if (ax <= 1.0f) return 1.0f + (v_near - 1.0f) * ax;
    return v_near + (v_far - v_near) * (ax - 1.0f);
}
}

void Coverflow::SetCardCount(int n) {
    total_ = (n > 0) ? n : 0;
    current_ = std::min(current_, (float)std::max(0, total_ - 1));
    target_  = std::min(target_,  (float)std::max(0, total_ - 1));
}

void Coverflow::Shift(int delta) {
    target_ += (float)delta;
}

void Coverflow::SnapTo(int idx) {
    target_  = (float)idx;
    current_ = (float)idx;
}

void Coverflow::Update(float dt) {
    float t = std::clamp(dt * lerpSpeed, 0.0f, 1.0f);
    current_ += (target_ - current_) * t;
    if (std::fabs(target_ - current_) < 1e-4f) current_ = target_;
}

int Coverflow::CenterCardIndex() const {
    if (total_ <= 0) return 0;
    int rounded = (int)std::lround(current_);
    int m = ((rounded % total_) + total_) % total_;
    return m;
}

Coverflow::Slot Coverflow::GetSlot(int i) const {
    // 이동 방향에 따라 base advance 시점을 다르게: 오른쪽 이동(current_<target_) 일 땐
    // ceil 로 base 를 미리 한 칸 전진시켜, 들어오는 카드가 우측 cull 영역(|pos|>cullPos)
    // 에서 화면 안으로 부드럽게 슬라이드 인 하도록 한다. 왼쪽 이동(floor) 은 이미 같은
    // 역할을 하므로 그대로. (5 카드 cyclic 구조 + 5 슬롯이라 슬롯 확장 대신 base 방향 보정.)
    int base = (current_ < target_)
        ? (int)std::ceil(current_)
        : (int)std::floor(current_);
    float frac = current_ - (float)base;

    int rawIdx = base + (i - config::kCenterSlot);
    int idx = total_ > 0 ? ((rawIdx % total_) + total_) % total_ : 0;

    float pos = (float)(i - config::kCenterSlot) - frac;
    float ax  = std::fabs(pos);

    float xDist   = InterpNearFar(ax, spacing[0], spacing[1]);
    float zd      = InterpNearFar(ax, zDepth[0],  zDepth[1]);
    float sc      = InterpScale(ax, scaleAt[0], scaleAt[1]);

    float yawMag  = InterpNearFar(ax, yawRad[0],  yawRad[1]);

    float xPos    = std::copysign(xDist, pos);
    // 부호 규약: 오른쪽 카드(pos>0) 에 음각을 주면 카드 정면이 바깥쪽(+X) 을 향함.
    // 단, |angleY| 가 카메라-카드 시야선 임계점(≈atan(xPos/|camZ-zd|)) 을 넘으면
    // backface culling=NONE 상태에서 뒷면이 보이며 visible normal 부호가 뒤집힌다.
    // 따라서 yawRad[1] 은 임계점보다 작게 유지해야 outer 카드가 outward 로 보임.
    float angleY  = -std::copysign(yawMag, pos);

    // |pos| > cullPos 면 fade out
    float visibility = 1.0f;
    if (ax > cullPos) {
        visibility = 0.0f;
    } else if (ax > cullPos - 0.5f) {
        visibility = std::clamp((cullPos - ax) / 0.5f, 0.0f, 1.0f);
    }

    XMMATRIX m =
        XMMatrixScaling(sc, sc, 1.0f) *
        XMMatrixRotationY(angleY) *
        XMMatrixTranslation(xPos, 0.0f, zd);

    Slot s{};
    XMStoreFloat4x4(&s.world, m);
    s.cardIndex  = idx;
    s.isCenter   = std::max(0.0f, 1.0f - ax);
    s.slotOffset = pos;
    s.visibility = visibility;
    return s;
}
