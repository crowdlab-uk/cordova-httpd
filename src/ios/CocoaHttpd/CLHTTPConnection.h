#import "HTTPConnection.h"

@class MultipartFormDataParser;

@interface CLHTTPConnection : HTTPConnection  {
  MultipartFormDataParser*        parser;
  NSFileHandle*          storeFile;
  NSString *currentUUID;
}
@property (strong, nonatomic) NSDictionary *mimeMap;

@end
