#import <Foundation/Foundation.h>

/// Netegram: decides which outgoing API calls never reach the network.
///
/// Ghost mode works by refusing to *tell the server* things — that you came online, that you
/// are typing, that you opened a chat. There is no client-side flag for any of that: the only
/// way to stay invisible is for the request never to leave the device.
///
/// Dropping a request outright would leave the caller waiting forever, so instead a plausible
/// success response is fabricated and handed back as if the server had answered. The rest of
/// the app cannot tell the difference, which is what keeps the UI from stalling.
///
/// The decision is made here, in MTProtoKit, because this is the last place the raw TL payload
/// of an outgoing call is visible — above this layer a "typing" notification and a "read
/// history" call are indistinguishable Swift values.
@interface MTNetegramGhost : NSObject

/// Returns the response to answer with instead of sending, or nil to let the call through.
/// `payload` is the serialised TL function, starting with its constructor id.
+ (NSData *)fakeResponseForPayload:(NSData *)payload;

@end
