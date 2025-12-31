#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "logo" asset catalog image resource.
static NSString * const ACImageNameLogo AC_SWIFT_PRIVATE = @"logo";

/// The "logoWithText" asset catalog image resource.
static NSString * const ACImageNameLogoWithText AC_SWIFT_PRIVATE = @"logoWithText";

#undef AC_SWIFT_PRIVATE
