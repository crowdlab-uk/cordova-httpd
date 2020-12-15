
#import "CLHTTPConnection.h"
#import "HTTPMessage.h"
#import "DDNumber.h"
#import "HTTPLogging.h"
#import "HTTPResponse.h"
#import "HTTPDataResponse.h"
#import "HTTPErrorResponse.h"

#import "MultipartFormDataParser.h"
#import "MultipartMessageHeaderField.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPFileResponse.h"


// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE; // | HTTP_LOG_FLAG_TRACE;


/**
 * All we have to do is override appropriate methods in HTTPConnection.
 **/

@implementation CLHTTPConnection

- init {
  currentUUID = nil;
  self.mimeMap = @{
    @"video/x-msvideo": @".avi",
    @"video/mpeg": @".mpeg",
    @"audio/mp3": @".mp3",
    @"audio/m4a": @".m4a",
    @"audio/x-m4a": @".m4a",
    @"audio/vnd.wave": @".wav",
    @"audio/wav": @".wav",
    @"audio/wave": @".wav",
    @"audio/x-wav": @".wav",
    @"video/mp4": @".mp4",
    @"video/ogv": @".ogg",
    @"video/quicktime": @".mov",
    @"image/jpeg": @".jpg",
    @"image/png": @".png",
    @"image/gif": @".gif",
    @"image/heic": @".heic",
    @"image/heix": @".heix",
    @"image/mif1": @".mif1",
    @"image/tiff": @".tiff",
    @"video/x-msvideo": @".avi",
    @"image/svg+xml": @".svg",
    @"audio/wav": @".wav",
    @"audio/webm": @".weba",
    @"video/webm": @".webm",
    @"image/webp": @".webp",
    @"video/3gpp": @".3gp",
    @"audio/3gpp": @".3gp",
    @"video/3gpp2": @".3g2",
    @"audio/3gpp2": @".3g2",
    @"image/x-adobe-dng": @".dng",
    @"image/x-sony-arw": @".arw",
    @"image/x-canon-cr2": @".cr2",
    @"image/x-canon-crw": @".crw",
    @"image/x-kodak-dcr": @".drc",
    @"image/x-epson-erf": @".erf",
    @"image/x-kodak-k25": @".k25",
    @"image/x-kodak-kdc": @".kdc",
    @"image/x-minolta-mrw": @".mrw",
    @"image/x-nikon-nef": @".nef",
    @"image/x-olympus-orf": @".orf",
    @"image/x-pentax-pef": @".pef",
    @"image/x-fuji-raf": @".raf",
    @"image/x-panasonic-raw": @".raw",
    @"image/x-sony-sr2": @".sr2",
    @"image/x-sony-srf": @".srf",
    @"image/x-sigma-x3f": @".x3f"
  };
  return [super init];
}

- (NSString *)fileExtensionAssociatedWithMimeType:(NSString *)mimeType {
  return [self.mimeMap objectForKey:mimeType];
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
  HTTPLogTrace();
  
  if ([method isEqualToString:@"OPTIONS"])
  {
    return YES;
  }
  
  // Add support for POST
  if ([method isEqualToString:@"POST"])
  {
    if ([path isEqualToString:@"/files"])
    {
      return YES;
    }
  }
  
  if ([method isEqualToString:@"GET"])
  {
    if ([path hasPrefix:@"/files"])
    {
      return YES;
    }
    if ([path isEqual:@"/isup"]) {
      return YES;
    }
  }
  
  if ([method isEqualToString:@"DELETE"])
  {
    if ([path hasPrefix:@"/files"])
    {
      return YES;
    }
  }
  
  return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path
{
  HTTPLogTrace();
  
  // Inform HTTP server that we expect a body to accompany a POST request
  if([method isEqualToString:@"POST"] && [path isEqualToString:@"/files"]) {
    // here we need to make sure, boundary is set in header
    NSString *contentType = [request headerField:@"Content-Type"];
    NSUInteger paramsSeparator = [contentType rangeOfString:@";"].location;
    if( NSNotFound == paramsSeparator ) {
      return NO;
    }
    if( paramsSeparator >= contentType.length - 1 ) {
      return NO;
    }
    NSString *type = [contentType substringToIndex:paramsSeparator];
    if( ![type isEqualToString:@"multipart/form-data"] ) {
      // we expect multipart/form-data content type
      return NO;
    }
    
    // enumerate all params in content-type, and find boundary there
    NSArray *params = [[contentType substringFromIndex:paramsSeparator + 1] componentsSeparatedByString:@";"];
    for( NSString *param in params ) {
      paramsSeparator = [param rangeOfString:@"="].location;
      if( (NSNotFound == paramsSeparator) || paramsSeparator >= param.length - 1 ) {
        continue;
      }
      NSString *paramName = [param substringWithRange:NSMakeRange(1, paramsSeparator-1)];
      NSString *paramValue = [param substringFromIndex:paramsSeparator+1];
      
      if( [paramName isEqualToString: @"boundary"] ) {
        // let's separate the boundary from content-type, to make it more handy to handle
        [request setHeaderField:@"boundary" value:paramValue];
      }
    }
    // check if boundary specified
    if( nil == [request headerField:@"boundary"] )  {
      return NO;
    }
    return YES;
  }
  return [super expectsRequestBodyFromMethod:method atPath:path];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
  HTTPLogTrace();
  
  NSError *error = NULL;
  NSRegularExpression *filesRegex =
  [NSRegularExpression regularExpressionWithPattern:@"/files/*"
                                            options:0
                                              error:&error];
  NSUInteger numberOfMatchesForFiles = [filesRegex numberOfMatchesInString:path
                                                              options:0
                                                                range:NSMakeRange(0, [path length])];
  BOOL matchesFiles = numberOfMatchesForFiles > 0;
  NSString *fileName = [path substringFromIndex:6];
  
  if ([method isEqual:@"OPTIONS"]) {
    NSLog(@"OPTIONS:%@", request.allHeaderFields);
    HTTPDataResponse *deleteResponse = [[HTTPDataResponse alloc] initWithData:[@"options" dataUsingEncoding:NSUTF8StringEncoding]];
    [deleteResponse.httpHeaders setValue:@"null" forKey:@"Access-Control-Allow-Origin"];
    [deleteResponse.httpHeaders setValue:@"OPTIONS, GET, POST, DELETE" forKey:@"Access-Control-Allow-Methods"];
    return deleteResponse;
  }
  
  NSRegularExpression *isUpRegex =
  [NSRegularExpression regularExpressionWithPattern:@"/isup"
                                            options:0
                                              error:&error];
  NSUInteger numberOfMatchesForIsUp = [isUpRegex numberOfMatchesInString:path
                                                              options:0
                                                                range:NSMakeRange(0, [path length])];
  
  if ([method isEqual:@"GET"] && numberOfMatchesForIsUp == 1) {
    HTTPDataResponse *isUpResponse = [[HTTPDataResponse alloc] initWithData:[@"up" dataUsingEncoding:NSUTF8StringEncoding]];
    [isUpResponse.httpHeaders setValue:@"null" forKey:@"Access-Control-Allow-Origin"];
//      [deleteResponse.httpHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
    return isUpResponse;
  }
  
  if ([method isEqual:@"DELETE"] && matchesFiles) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *mediaPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/media/"];
    
    NSString *filePath = [mediaPath stringByAppendingPathComponent:fileName];
    NSError *error;
    BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    if (success) {
      HTTPDataResponse *deleteResponse = [[HTTPDataResponse alloc] initWithData:[@"deleted" dataUsingEncoding:NSUTF8StringEncoding]];
      [deleteResponse.httpHeaders setValue:@"null" forKey:@"Access-Control-Allow-Origin"];
//      [deleteResponse.httpHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
      return deleteResponse;
    } else {
      HTTPErrorResponse *deleteResponse = [[HTTPErrorResponse alloc] initWithErrorCode:404];
      [deleteResponse.httpHeaders setValue:@"null" forKey:@"Access-Control-Allow-Origin"];
//      [deleteResponse.httpHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
      return deleteResponse;
    }
  }
  
  if ([method isEqual:@"POST"] && matchesFiles) {
    HTTPDataResponse *response = [[HTTPDataResponse alloc] initWithData:[[NSString stringWithFormat:@"{\"uuid\":\"%@\"}", currentUUID] dataUsingEncoding:NSUTF8StringEncoding]];
    [response.httpHeaders setObject:@"null" forKey:@"Access-Control-Allow-Origin"];
//    [response.httpHeaders setObject:@"true" forKey:@"Access-Control-Allow-Credentials"];
    return response;
  }
  
  if ([method isEqual:@"GET"] && matchesFiles) {
    NSString *mediaPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/media/"];
    NSString *filePath = [mediaPath stringByAppendingPathComponent:[path substringFromIndex:@"/files/".length]];
    
    HTTPFileResponse *response = [[HTTPFileResponse alloc] initWithFilePath: filePath forConnection:self];
    [response.httpHeaders setValue:@"null" forKey:@"Access-Control-Allow-Origin"];
//    [response.httpHeaders setValue:@"true" forKey:@"Access-Control-Allow-Credentials"];
    return response;
  }
  
  return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
  HTTPLogTrace();
  
  // set up mime parser
  NSString *boundary = [request headerField:@"boundary"];
  parser = [[MultipartFormDataParser alloc] initWithBoundary:boundary formEncoding:NSUTF8StringEncoding];
  parser.delegate = self;
}

- (void)processBodyData:(NSData *)postDataChunk
{
  HTTPLogTrace();
  // append data to the parser. It will invoke callbacks to let us handle
  // parsed data.
  [parser appendData:postDataChunk];
}


//-----------------------------------------------------------------
#pragma mark multipart form data parser delegate


- (void) processStartOfPartWithHeader:(MultipartMessageHeader*) header {
  // in this sample, we are not interested in parts, other then file parts.
  // check content disposition to find out filename
  
  currentUUID = [[NSUUID new] UUIDString];
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *mediaPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString:@"/media/"];
  
  BOOL isDir;
  if (!([fileManager fileExistsAtPath:mediaPath isDirectory:&isDir] && isDir)) {
    [fileManager createDirectoryAtPath:mediaPath withIntermediateDirectories:YES attributes:@{} error:nil];
  }
  // HERE
  if (self.mimeMap == nil) {
    self.mimeMap = @{
      @"video/x-msvideo": @".avi",
      @"video/mpeg": @".mpeg",
      @"audio/mp3": @".mp3",
      @"audio/m4a": @".m4a",
      @"audio/x-m4a": @".m4a",
      @"audio/vnd.wave": @".wav",
      @"audio/wav": @".wav",
      @"audio/wave": @".wav",
      @"audio/x-wav": @".wav",
      @"video/mp4": @".mp4",
      @"video/ogv": @".ogg",
      @"video/quicktime": @".mov",
      @"image/jpeg": @".jpg",
      @"image/png": @".png",
      @"image/gif": @".gif",
      @"image/heic": @".heic",
      @"image/heix": @".heix",
      @"image/mif1": @".mif1",
      @"image/tiff": @".tiff",
      @"video/x-msvideo": @".avi",
      @"image/svg+xml": @".svg",
      @"audio/wav": @".wav",
      @"audio/webm": @".weba",
      @"video/webm": @".webm",
      @"image/webp": @".webp",
      @"video/3gpp": @".3gp",
      @"audio/3gpp": @".3gp",
      @"video/3gpp2": @".3g2",
      @"audio/3gpp2": @".3g2",
      @"image/x-adobe-dng": @".dng",
      @"image/x-sony-arw": @".arw",
      @"image/x-canon-cr2": @".cr2",
      @"image/x-canon-crw": @".crw",
      @"image/x-kodak-dcr": @".drc",
      @"image/x-epson-erf": @".erf",
      @"image/x-kodak-k25": @".k25",
      @"image/x-kodak-kdc": @".kdc",
      @"image/x-minolta-mrw": @".mrw",
      @"image/x-nikon-nef": @".nef",
      @"image/x-olympus-orf": @".orf",
      @"image/x-pentax-pef": @".pef",
      @"image/x-fuji-raf": @".raf",
      @"image/x-panasonic-raw": @".raw",
      @"image/x-sony-sr2": @".sr2",
      @"image/x-sony-srf": @".srf",
      @"image/x-sigma-x3f": @".x3f"
    };
  }
  
  NSString *fileExtension = [self fileExtensionAssociatedWithMimeType:[header.fields objectForKey:@"Content-Type"]];
  
  if (fileExtension == nil) {
    fileExtension = @"";
  }
  
  NSString *fileName = currentUUID = [currentUUID stringByAppendingString:fileExtension];
  NSString *filePath = [mediaPath stringByAppendingPathComponent:fileName];
  
  if( [[NSFileManager defaultManager] fileExistsAtPath:filePath] ) {
    storeFile = nil;
  } else {
    HTTPLogVerbose(@"Saving file to %@", filePath);
    if(![[NSFileManager defaultManager] createDirectoryAtPath:mediaPath withIntermediateDirectories:true attributes:nil error:nil]) {
      HTTPLogError(@"Could not create directory at path: %@", filePath);
    }
    if(![[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil]) {
      HTTPLogError(@"Could not create file at path: %@", filePath);
    }
    storeFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
  }
}


- (void) processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header
{
  // here we just write the output from parser to the file.
  if (storeFile) {
    [storeFile writeData:data];
  }
}

- (void) processEndOfPartWithHeader:(MultipartMessageHeader*) header
{
  // as the file part is over, we close the file.
  [storeFile closeFile];
  storeFile = nil;
}

- (void) processPreambleData:(NSData*) data
{
  // if we are interested in preamble data, we could process it here.
  
}

- (void) processEpilogueData:(NSData*) data
{
  // if we are interested in epilogue data, we could process it here.
  
}

@end
