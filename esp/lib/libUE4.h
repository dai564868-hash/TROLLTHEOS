#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "pid.h"
#include "UtfTool.hpp"
#include "office.hpp"
#define kuan [UIScreen mainScreen].bounds.size.width
#define gao [UIScreen mainScreen].bounds.size.height

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Imgui Colors ===
#define Colour_Red 0xFF0000FF
#define Colour_Green 0xFF00FF00
#define Colour_Pink 0xFFCBC0FF
#define Colour_Blue 0xFFFF0000
#define Colour_LightBlue 0xFFFACE87
#define Colour_Cyan 0xFFFFFF00
#define Colour_Emerald 0xFFAAFF7F
#define Colour_GrassGreen 0xFF00FC7C
#define Colour_Orange 0xFF00A5FF
#define Colour_DarkOrange 0xFF0066FF
#define Colour_Peach 0xFFB9DAFF
#define Colour_Coral 0xFF507FFF
#define Colour_Purple 0xFFEE677A
#define Colour_SlateGray 0xFF908070
#define Colour_White 0xFFFFFFFF
#define Colour_Black 0xFF000000
#define Colour_Lime 0xFFADFF2F
#define Colour_Yellow 0xFF00FFFF
#define Colour_TransparentRed 0x800000FF
#define Colour_TransparentOrange 0x8000A5FF
#define Colour_TransparentLime 0x80ADFF2F
#define Colour_TransparentGreen 0x8000FF00
#define Colour_TransparentSlateGray 0x80908070

static uintptr_t GetFieldAddress(std::string address) {
    return (uintptr_t)strtoul(address.c_str(), nullptr, 16);
}


static bool vm_readv(void *address, void *buffer, size_t length) {
    vm_size_t size = 0;
    kern_return_t error = vm_read_overwrite(mach_task_self(), (vm_address_t)address, length, (vm_address_t)buffer, &size);
    if (error != KERN_SUCCESS || size != length)
        return false;
    return true;
}

static bool vm_writev(void *address, const void *buffer, size_t length) {
    kern_return_t error = vm_write(mach_task_self(), (vm_address_t)address, (vm_address_t)buffer, (mach_msg_type_number_t)length);
    return (error == KERN_SUCCESS);
}

static bool Write_data(kaddr address, size_t length, const char* buffer) {
    return vm_writev((void*)address, buffer, length);
}

// Kiểm tra xem chuỗi str có chứa chuỗi con substr không
static bool isContain(std::string str, const char* check) {
    size_t found = str.find(check);
    return (found != std::string::npos);
}

template<typename ... Args>
static std::string string_format(const std::string& format, Args ... args) {
    size_t size = 1 + snprintf(nullptr, 0, format.c_str(), args ...); // Tính độ dài chuỗi sau khi định dạng
    char bytes[size]; // Lưu trữ chuỗi đã định dạng
    snprintf(bytes, size, format.c_str(), args ...); // Định dạng chuỗi và lưu vào bytes
    return std::string(bytes); // Chuyển bytes thành string và trả về
}

// Đọc thông tin ký tự
static void getUTF8(UTF8 * buf, unsigned long namepy) {
    UTF16 buf16[64] = { 0 };             // Tăng lên 64 ký tự UTF-16
    vm_readv((void *)namepy, buf16, sizeof(buf16));

    UTF16 *pTempUTF16 = buf16;
    UTF8 *pTempUTF8 = buf;
    UTF8 *pUTF8End = pTempUTF8 + 180;    // 60 ký tự UTF-8 (mỗi ký tự max 3 byte)

    while (pTempUTF16 < buf16 + 64) {
        if (*pTempUTF16 <= 0x007F && pTempUTF8 + 1 < pUTF8End) {
            *pTempUTF8++ = (UTF8)*pTempUTF16;
        }
        else if (*pTempUTF16 >= 0x0080 && *pTempUTF16 <= 0x07FF && pTempUTF8 + 2 < pUTF8End) {
            *pTempUTF8++ = (*pTempUTF16 >> 6) | 0xC0;
            *pTempUTF8++ = (*pTempUTF16 & 0x3F) | 0x80;
        }
        else if (*pTempUTF16 >= 0x0800 && *pTempUTF16 <= 0xFFFF && pTempUTF8 + 3 < pUTF8End) {
            *pTempUTF8++ = (*pTempUTF16 >> 12) | 0xE0;
            *pTempUTF8++ = ((*pTempUTF16 >> 6) & 0x3F) | 0x80;
            *pTempUTF8++ = (*pTempUTF16 & 0x3F) | 0x80;
        }
        else {
            break;
        }
        pTempUTF16++;
    }

    *pTempUTF8 = '\0';  // Null-terminate
}

/*
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* ________________________________________LDVQuang__________________________________________________
* Create by LDVQuang (my github https://github.com/LDVQuang2306) contact me https://t.me/quangmodmap 
* 
* 
* create on 31/12/2025 by @quangmodmap
*/

struct Vector2 {
    float X;
    float Y;

    Vector2() {
        this->X = 0;
        this->Y = 0;
    }
    Vector2(float x, float y) {
        this->X = x;
        this->Y = y;
    }

    static Vector2 Zero() {
        return Vector2(0.0f, 0.0f);
    }

    static float Distance(Vector2 a, Vector2 b) {
        Vector2 vector = Vector2(a.X - b.X, a.Y - b.Y);
        return sqrt((vector.X * vector.X) + (vector.Y * vector.Y));
    }

    bool operator!=(const Vector2 &src) const {
        return (src.X != X) || (src.Y != Y);
    }
    Vector2 operator+(const Vector2 &v) const {
        return Vector2(X + v.X, Y + v.Y);
    }
    Vector2 operator-(const Vector2 &v) const {
        return Vector2(X - v.X, Y - v.Y);
    }
    Vector2 operator/(const float A) {
        return Vector2(this->X / A, this->Y / A);
    }
    Vector2 &operator+=(const Vector2 &v) {
        X += v.X;
        Y += v.Y;
        return *this;
    }
    Vector2 &operator-=(const Vector2 &v) {
        X -= v.X;
        Y -= v.Y;
        return *this;
    }
    float Size() {
        return sqrt((this->X * this->X) + (this->Y * this->Y));
    }
};

struct Vector3 {
    float X;
    float Y;
    float Z;

    Vector3() {
        this->X = 0;
        this->Y = 0;
        this->Z = 0;
    }

    Vector3(float x, float y, float z) {
        this->X = x;
        this->Y = y;
        this->Z = z;
    }

    float Size() const {
        return sqrt(X * X + Y * Y + Z * Z);
    }

    Vector3 Normalize() const {
        float length = Size();
        if (length != 0.0f) {
            return Vector3(X / length, Y / length, Z / length);
        } else {
            return Vector3(0.0f, 0.0f, 0.0f);
        }
    }

    Vector3 Cross(const Vector3& v) const {
        return Vector3(
            Y * v.Z - Z * v.Y,
            Z * v.X - X * v.Z,
            X * v.Y - Y * v.X
        );
    }

    Vector3 operator+(const Vector3 &v) const {
        return Vector3(X + v.X, Y + v.Y, Z + v.Z);
    }

    Vector3 operator-(const Vector3 &v) const {
        return Vector3(X - v.X, Y - v.Y, Z - v.Z);
    }

    bool operator==(const Vector3 &v) const {
        return X == v.X && Y == v.Y && Z == v.Z;
    }

    bool operator!=(const Vector3 &v) const {
        return !(*this == v);
    }

    Vector3 operator-=(const Vector3 &A) {
        this->X -= A.X;
        this->Y -= A.Y;
        this->Z -= A.Z;
        return *this;
    }

    Vector3 operator-=(const float A) {
        this->X -= A;
        this->Y -= A;
        this->Z -= A;
        return *this;
    }

    Vector3 operator/(const float A) const {
        return Vector3(this->X / A, this->Y / A, this->Z / A);
    }

    Vector3 operator*(float a) const {
        return Vector3(X * a, Y * a, Z * a);
    }

    static Vector3 Zero() {
        return Vector3(0.0f, 0.0f, 0.0f);
    }

    static float Dot(Vector3 a, Vector3 b) {
        return a.X * b.X + a.Y * b.Y + a.Z * b.Z;
    }

    static float Distance(Vector3 a, Vector3 b) {
        Vector3 vector = Vector3(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
        return sqrt(vector.X * vector.X + vector.Y * vector.Y + vector.Z * vector.Z);
    }
    float Length() const {
        return Distance(*this, Vector3{0.0f, 0.0f, 0.0f});
    }
};
static float Dot(Vector3 lhs, Vector3 rhs) {
    return (((lhs.X * rhs.X) + (lhs.Y * rhs.Y)) + (lhs.Z * rhs.Z));
}

struct VectorRect {
    int x;
    int y;
    int w;
    int h;
};

typedef struct FVectorRect {
    float X;
    float Y;
    float W;
    float H;
} FVectorRect;

struct FMatrix {
    float Matrix[4][4];

    float *operator[](int index) {
        return Matrix[index];
    }
};

struct Rotator {
    float Y;//P
    float X;//Y
    float Roll;
};

struct Tracking {
    Rotator aim_angle;
    Vector3 loc;
};

struct FRotator {
    float Pitch;
    float Yaw;
    float Roll;
    inline FRotator() : Pitch(0.0f), Yaw(0.0f), Roll(0.0f) {}
    inline FRotator(float pitch, float yaw, float roll) : Pitch(pitch), Yaw(yaw), Roll(roll) {}
    inline FRotator operator+(const FRotator &A) {
        return FRotator(this->Pitch + A.Pitch, this->Yaw + A.Yaw, this->Roll + A.Roll);
    }
    inline FRotator operator-(const FRotator &A) {
        return FRotator(this->Pitch - A.Pitch, this->Yaw - A.Yaw, this->Roll - A.Roll);
    }
    inline FRotator operator*(const FRotator &A) {
        return FRotator(this->Pitch * A.Pitch, this->Yaw * A.Yaw, this->Roll * A.Roll);
    }
    inline FRotator operator*(const float A) {
        return FRotator(this->Pitch * A, this->Yaw * A, this->Roll * A);
    }
    inline FRotator operator/(const FRotator &A) {
        return FRotator(this->Pitch / A.Pitch, this->Yaw / A.Yaw, this->Roll / A.Roll);
    }
    inline FRotator operator/(const float A) {
        return FRotator(this->Pitch / A, this->Yaw / A, this->Roll / A);
    }
    inline float Size() {
        return sqrt((this->Pitch * this->Pitch) + (this->Yaw * this->Yaw) + (this->Roll * this->Roll));
    }
    static Vector3 Vector3ToRotation(Vector3 v1) {
        Vector3 V = Vector3(0, 0, 0);
        V.Y = atan2(v1.Y, v1.X);
        V.X = atan2(v1.Z, sqrt(v1.X * v1.X + v1.Y * v1.Y));
        V.Z = 0;
        return V;
    }
};

struct MinimalViewInfo {
    Vector3 Location;
    Vector3 LocationLocalSpace;
    FRotator Rotation;
    char ViewTag[0xC];
    float FOV;
};

struct Vector4 {
    float x;
    float y;
    float z;
    float w;
};

struct D3DXMATRIX {
    float _11, _12, _13, _14;
    float _21, _22, _23, _24;
    float _31, _32, _33, _34;
    float _41, _42, _43, _44;
};


struct FTransform {
    Vector4 rot;
    Vector3 translation;
    Vector3 scale;
    D3DXMATRIX ToMatrixWithScale() {
        D3DXMATRIX m;
        m._41 = translation.X;
        m._42 = translation.Y;
        m._43 = translation.Z;

        float x2 = rot.x + rot.x;
        float y2 = rot.y + rot.y;
        float z2 = rot.z + rot.z;

        float xx2 = rot.x * x2;
        float yy2 = rot.y * y2;
        float zz2 = rot.z * z2;
        m._11 = (1.0f - (yy2 + zz2)) * scale.X;
        m._22 = (1.0f - (xx2 + zz2)) * scale.Y;
        m._33 = (1.0f - (xx2 + yy2)) * scale.Z;

        float yz2 = rot.y * z2;
        float wx2 = rot.w * x2;
        m._32 = (yz2 - wx2) * scale.Z;
        m._23 = (yz2 + wx2) * scale.Y;

        float xy2 = rot.x * y2;
        float wz2 = rot.w * z2;
        m._21 = (xy2 - wz2) * scale.Y;
        m._12 = (xy2 + wz2) * scale.X;

        float xz2 = rot.x * z2;
        float wy2 = rot.w * y2;
        m._31 = (xz2 + wy2) * scale.Z;
        m._13 = (xz2 - wy2) * scale.X;

        m._14 = 0.0f;
        m._24 = 0.0f;
        m._34 = 0.0f;
        m._44 = 1.0f;

        return m;
    }
    static D3DXMATRIX MatrixMultiplication(D3DXMATRIX pM1, D3DXMATRIX pM2) {
        D3DXMATRIX pOut;
        pOut._11 = pM1._11 * pM2._11 + pM1._12 * pM2._21 + pM1._13 * pM2._31 + pM1._14 * pM2._41;
        pOut._12 = pM1._11 * pM2._12 + pM1._12 * pM2._22 + pM1._13 * pM2._32 + pM1._14 * pM2._42;
        pOut._13 = pM1._11 * pM2._13 + pM1._12 * pM2._23 + pM1._13 * pM2._33 + pM1._14 * pM2._43;
        pOut._14 = pM1._11 * pM2._14 + pM1._12 * pM2._24 + pM1._13 * pM2._34 + pM1._14 * pM2._44;
        pOut._21 = pM1._21 * pM2._11 + pM1._22 * pM2._21 + pM1._23 * pM2._31 + pM1._24 * pM2._41;
        pOut._22 = pM1._21 * pM2._12 + pM1._22 * pM2._22 + pM1._23 * pM2._32 + pM1._24 * pM2._42;
        pOut._23 = pM1._21 * pM2._13 + pM1._22 * pM2._23 + pM1._23 * pM2._33 + pM1._24 * pM2._43;
        pOut._24 = pM1._21 * pM2._14 + pM1._22 * pM2._24 + pM1._23 * pM2._34 + pM1._24 * pM2._44;
        pOut._31 = pM1._31 * pM2._11 + pM1._32 * pM2._21 + pM1._33 * pM2._31 + pM1._34 * pM2._41;
        pOut._32 = pM1._31 * pM2._12 + pM1._32 * pM2._22 + pM1._33 * pM2._32 + pM1._34 * pM2._42;
        pOut._33 = pM1._31 * pM2._13 + pM1._32 * pM2._23 + pM1._33 * pM2._33 + pM1._34 * pM2._43;
        pOut._34 = pM1._31 * pM2._14 + pM1._32 * pM2._24 + pM1._33 * pM2._34 + pM1._34 * pM2._44;
        pOut._41 = pM1._41 * pM2._11 + pM1._42 * pM2._21 + pM1._43 * pM2._31 + pM1._44 * pM2._41;
        pOut._42 = pM1._41 * pM2._12 + pM1._42 * pM2._22 + pM1._43 * pM2._32 + pM1._44 * pM2._42;
        pOut._43 = pM1._41 * pM2._13 + pM1._42 * pM2._23 + pM1._43 * pM2._33 + pM1._44 * pM2._43;
        pOut._44 = pM1._41 * pM2._14 + pM1._42 * pM2._24 + pM1._43 * pM2._34 + pM1._44 * pM2._44;

        return pOut;
    }
};


static FMatrix MatrixMulti(FMatrix m1, FMatrix m2) {
    FMatrix matrix = FMatrix();
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            for (int k = 0; k < 4; k++) {
                matrix[i][j] += m1[i][k] * m2[k][j];
            }
        }
    }
    return matrix;
}


static FMatrix RotatorToMatrix(FRotator rotation) {
    float radPitch = rotation.Pitch * ((float) M_PI / 180.0f);
    float radYaw = rotation.Yaw * ((float) M_PI / 180.0f);
    float radRoll = rotation.Roll * ((float) M_PI / 180.0f);
    
    float SP = sinf(radPitch);
    float CP = cosf(radPitch);
    float SY = sinf(radYaw);
    float CY = cosf(radYaw);
    float SR = sinf(radRoll);
    float CR = cosf(radRoll);
    
    FMatrix matrix;
    
    matrix[0][0] = (CP * CY);
    matrix[0][1] = (CP * SY);
    matrix[0][2] = (SP);
    matrix[0][3] = 0;
    
    matrix[1][0] = (SR * SP * CY - CR * SY);
    matrix[1][1] = (SR * SP * SY + CR * CY);
    matrix[1][2] = (-SR * CP);
    matrix[1][3] = 0;
    
    matrix[2][0] = (-(CR * SP * CY + SR * SY));
    matrix[2][1] = (CY * SR - CR * SP * SY);
    matrix[2][2] = (CR * CP);
    matrix[2][3] = 0;
    
    matrix[3][0] = 0;
    matrix[3][1] = 0;
    matrix[3][2] = 0;
    matrix[3][3] = 1;
    
    return matrix;
}

static Vector2 WorldToScreen(Vector3 worldLocation, MinimalViewInfo camViewInfo, int width, int height) {
    FMatrix tempMatrix = RotatorToMatrix(camViewInfo.Rotation);
    
    Vector3 vAxisX(tempMatrix[0][0], tempMatrix[0][1], tempMatrix[0][2]);
    Vector3 vAxisY(tempMatrix[1][0], tempMatrix[1][1], tempMatrix[1][2]);
    Vector3 vAxisZ(tempMatrix[2][0], tempMatrix[2][1], tempMatrix[2][2]);
    
    Vector3 vDelta = worldLocation - camViewInfo.Location;
    
    Vector3 vTransformed(Dot(vDelta, vAxisY), Dot(vDelta, vAxisZ), Dot(vDelta, vAxisX));
    
    if (vTransformed.Z < 1.0f) {
        vTransformed.Z = 1.0f;
    }
    
    float fov = camViewInfo.FOV;
    float screenCenterX = (width / 2.0f);
    float screenCenterY = (height / 2.0f);
    
    return Vector2((screenCenterX + vTransformed.X * (screenCenterX / tanf(fov * ((float) M_PI / 360.0f))) / vTransformed.Z),
                   (screenCenterY - vTransformed.Y * (screenCenterX / tanf(fov * ((float) M_PI / 360.0f))) / vTransformed.Z));
}

static Vector2 WorldToScreenmatrix(Vector3 obj, float* matrix, float width, float height) {
    Vector2 screen = { -1.0f, -1.0f };
    
    float clipX = matrix[0] * obj.X + matrix[4] * obj.Y + matrix[8] * obj.Z + matrix[12];
    float clipY = matrix[1] * obj.X + matrix[5] * obj.Y + matrix[9] * obj.Z + matrix[13];
    float clipZ = matrix[2] * obj.X + matrix[6] * obj.Y + matrix[10] * obj.Z + matrix[14]; // 新增 Z 分量计算
    float clipW = matrix[3] * obj.X + matrix[7] * obj.Y + matrix[11] * obj.Z + matrix[15];
    
    if (clipW <= 0.001f) return screen;
    
    float ndcX = clipX / clipW;
    float ndcY = clipY / clipW;
    float ndcZ = clipZ / clipW;
    
    if (ndcX < -1.0f || ndcX > 1.0f ||
        ndcY < -1.0f || ndcY > 1.0f ||
        ndcZ < -1.0f || ndcZ > 1.0f) { // 新增 Z 轴范围检查
        return screen;
    }
    
    screen.X = (ndcX + 1.0f) * 0.5f * width;
    screen.Y = (1.0f - ndcY) * 0.5f * height;
    
    return screen;
}


static Vector2 WorldToScreen2(Vector3 worldLocation, MinimalViewInfo camViewInfo,float width, float height) {
    FMatrix tempMatrix = RotatorToMatrix(camViewInfo.Rotation);
    
    Vector3 vAxisX(tempMatrix[0][0], tempMatrix[0][1], tempMatrix[0][2]);
    Vector3 vAxisY(tempMatrix[1][0], tempMatrix[1][1], tempMatrix[1][2]);
    Vector3 vAxisZ(tempMatrix[2][0], tempMatrix[2][1], tempMatrix[2][2]);
    
    Vector3 vDelta = worldLocation - camViewInfo.Location;
    
    Vector3 vTransformed(Vector3::Dot(vDelta, vAxisY), Vector3::Dot(vDelta, vAxisZ), Vector3::Dot(vDelta, vAxisX));
    
    if (vTransformed.Z < 1.0f) {
        vTransformed.Z = 1.0f;
    }
    
    float fov = camViewInfo.FOV;
    float screenCenterX =kuan;
    float screenCenterY =gao;
    
    return Vector2((screenCenterX + vTransformed.X * (screenCenterX / tanf(fov * ((float) M_PI / 360.0f))) / vTransformed.Z),
                   (screenCenterY - vTransformed.Y * (screenCenterX / tanf(fov * ((float) M_PI / 360.0f))) / vTransformed.Z));
}


static Vector3 GetBoneFTransform(uintptr_t Mesh, const int Id) {
    uintptr_t BoneActor = QuangRead<long>(Mesh + (GetFieldAddress(kBoneActor) + 0x18));
    FTransform lpFTransform = QuangRead<FTransform>(BoneActor + Id * 0x30);
    FTransform ComponentToWorld = QuangRead<FTransform>(Mesh + GetFieldAddress(kGetComponentToWorld));
    D3DXMATRIX Matrix = FTransform::MatrixMultiplication(lpFTransform.ToMatrixWithScale(), ComponentToWorld.ToMatrixWithScale());
    return Vector3(Matrix._41, Matrix._42, Matrix._43);
}

static Vector3 GetRelativeLocation(long actor) {
    return QuangRead<Vector3>(QuangRead<long>(actor + GetFieldAddress(KGetActorLocation)) + GetFieldAddress(KGetActorRocation));
}

static bool GetInsideFov(Vector2 PlayerBone, float FovRadius) {
    Vector2 Cenpoint;
    Cenpoint.X = PlayerBone.X - kuan / 2;
    Cenpoint.Y = PlayerBone.Y - gao / 2;
    return Cenpoint.X * Cenpoint.X + Cenpoint.Y * Cenpoint.Y <= FovRadius * FovRadius;
}

static int GetCenterOffsetForVector(Vector2 point) {
    return sqrt(pow(point.X - kuan / 2, 2) + pow(point.Y - gao / 2, 2));
}

static FRotator Clamp(FRotator r) {
    if (r.Yaw > 180.f)
        r.Yaw -= 360.f;
    else if (r.Yaw < -180.f)
        r.Yaw += 360.f;

    if (r.Pitch > 180.f)
        r.Pitch -= 360.f;
    else if (r.Pitch < -180.f)
        r.Pitch += 360.f;

    if (r.Pitch < -89.f)
        r.Pitch = -89.f;
    else if (r.Pitch > 89.f)
        r.Pitch = 89.f;

    r.Roll = 0.f;

    return r;
}

static FRotator ToRotator(Vector3 aimPos, Vector3 target) {
    Vector3 rotation = aimPos - target;
    float hyp = sqrt(rotation.X * rotation.X + rotation.Y * rotation.Y);
    FRotator newViewAngle = FRotator();
    newViewAngle.Pitch = -atan(rotation.Z / hyp) * (180.f / M_PI);
    newViewAngle.Yaw = atan(rotation.Y / rotation.X) * (180.f / M_PI);
    newViewAngle.Roll = 0.f;

    if (rotation.X >= 0.f)
        newViewAngle.Yaw += 180.0f;

    return newViewAngle;
}

static int BoneColos(bool b1, bool b2, bool isAi) {
    if (isAi) return b1 || b2 ? Colour_Green : Colour_White;
    else return b1 || b2 ? Colour_Green : Colour_Red;
}

NS_ASSUME_NONNULL_END