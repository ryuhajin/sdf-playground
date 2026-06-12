#pragma once
#include <DirectXMath.h>

#include "Config.h"

class Coverflow {
public:
    struct Slot {
        DirectX::XMFLOAT4X4 world;
        int   cardIndex;
        float isCenter;     // 0..1 (1 at center)
        float slotOffset;   // signed slot position incl. frac
        float visibility;   // 0..1, |pos|>cullPos 일때 0
    };

    void SetCardCount(int n);
    void Shift(int delta);
    void SnapTo(int idx);
    void Update(float dt);

    Slot GetSlot(int i) const;          // i ∈ [0..4]
    int  CenterCardIndex() const;
    int  Total() const { return total_; }

    // Visual tuning. 인덱스 0 = near (|pos|=1), 1 = far (|pos|=2).
    // |pos| 가 0..1 사이면 (0, near) 보간, 1..2 사이면 (near, far) 보간.
    float spacing[2] = { config::kSpacingNear, config::kSpacingFar };
    float yawRad[2]  = { config::kYawNearRad,  config::kYawFarRad  };
    float zDepth[2]  = { config::kZDepthNear,  config::kZDepthFar  };
    float scaleAt[2] = { config::kScaleNear,   config::kScaleFar   };
    float cullPos    = config::kCullPos;
    float lerpSpeed  = config::kLerpSpeed;

private:
    int   total_   = 0;
    float current_ = 0.0f;
    float target_  = 0.0f;
};
