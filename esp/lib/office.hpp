

#include <iostream>
#include <string>
#include <sstream>
#include <cstdint>

#ifndef office_h
#define office_h


// Thông tin đội
#define kMYUGPTeamComponent "0x1068"    // Component đội struct UGPTeamComponent* TeamComp;
#define kMyTeamId "0x108"              // ID đội của tôi
#define kMyCampId "0x10C"              // ID phe của tôi

#define kPLevel "0xF8"
// Actors (các đối tượng trong game)
#define kActors "0x98"                 // Danh sách actors
#define kCount "0xA0"                  // Số lượng

// Thông tin đối tượng
#define kclass_id "0x1C"               // ID class
#define kDead "0xD80"                  // Trạng thái chết struct FDeadInfo DeadInfo;
#define kAPlayerState "0x390"          // Trạng thái người chơi
#define kbIsAI "0x39E"                 // Có phải AI không
#define kMesh "0x3d0"                  // Mesh 3D
#define kBoneActor "0x700"             // Actor xương
#define kGetComponentToWorld "0x210"   // Lấy component đến thế giới
#define KGetActorLocation "0x180"      // Lấy vị trí actor
#define KGetActorRocation "0x220"      // Lấy xoay actor


#define KRootComponent "0x190" // struct FVector ComponentVelocity;
#define kRelativeRotation "0x178"//struct FRotator RelativeRotation;

#endif 
