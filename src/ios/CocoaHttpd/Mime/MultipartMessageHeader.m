//
//  MultipartMessagePart.m
//  HttpServer
//
//  Created by Валерий Гаврилов on 29.03.12.
//  Copyright (c) 2012 LLC "Online Publishing Partners" (onlinepp.ru). All rights reserved.

#import "MultipartMessageHeader.h"
#import "MultipartMessageHeaderField.h"

#import "HTTPLogging.h"

//-----------------------------------------------------------------
#pragma mark log level

#ifdef DEBUG
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#endif

//-----------------------------------------------------------------
// implementation MultipartMessageHeader
//-----------------------------------------------------------------


@implementation MultipartMessageHeader
@synthesize fields,encoding;


- (id) initWithData:(NSData *)data formEncoding:(NSStringEncoding) formEncoding {
	if( nil == (self = [super init]) ) {
        return self;
    }
	
	fields = [[NSMutableDictionary alloc] initWithCapacity:1];

	// In case encoding is not mentioned,
	encoding = contentTransferEncoding_unknown;

	char* bytes = (char*)data.bytes;
	NSUInteger length = data.length;
  
  char newBytes[2048];
  int i=0;
  while (i < length) {
    newBytes[i] = bytes[i];
    ++i;
  }
  newBytes[i] = 0;
  
  NSString *headersRaw = [NSString stringWithCString:newBytes encoding:NSUTF8StringEncoding];
  NSArray *splitHeaders = [headersRaw componentsSeparatedByString:@"\r\n"];
  
  for (i=0; i < [splitHeaders count]; ++i) {
    if (![splitHeaders[i] containsString:@":"]) {
      continue;
    }
    NSArray *headerParts = [splitHeaders[i] componentsSeparatedByString:@":"];
    if ([headerParts count] < 2) {
      continue;
    }
    NSString *key = [headerParts objectAtIndex:0];
    NSString *value = [headerParts objectAtIndex:1];
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    
    [fields setObject:value forKey:key];
  }
	
	if( !fields.count ) {
		// it was an empty header.
		// we have to set default values.
		// default header.
		[fields setObject:@"text/plain" forKey:@"Content-Type"];
	}

	return self;
}

- (NSString *)description {	
	return [NSString stringWithFormat:@"%@",fields];
}


@end
