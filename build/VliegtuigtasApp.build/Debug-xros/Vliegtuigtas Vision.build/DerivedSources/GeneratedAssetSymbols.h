#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AppIcon/Middle/Content" asset catalog image resource.
static NSString * const ACImageNameAppIconMiddleContent AC_SWIFT_PRIVATE = @"AppIcon/Middle/Content";

/// The "AppIcon/Back/Content" asset catalog image resource.
static NSString * const ACImageNameAppIconBackContent AC_SWIFT_PRIVATE = @"AppIcon/Back/Content";

#undef AC_SWIFT_PRIVATE
