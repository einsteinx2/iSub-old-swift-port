//
//  SubsonicServerEditViewController.m
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SubsonicServerEditViewController.h"
#import "Imports.h"
#import "iSub-Swift.h"

#define kBadUrlTag 1
#define kBadUserTag 2
#define kBadPassTag 3

@interface SubsonicServerEditViewController() <UIAlertViewDelegate, ApiLoaderDelegate>
@property (nonatomic, strong) IBOutlet UITextField *urlField;
@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIButton *saveButton;
- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;
@end

@implementation SubsonicServerEditViewController

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    if (SavedSettings.si.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark - Lifecycle

- (instancetype) initWithServer:(Server *)server
{
    if (self = [super initWithNibName:@"SubsonicServerEditViewController" bundle:nil])
    {
        _server = server;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    CGRect frame = self.view.frame;
    frame.origin.y = 20;
    self.view.frame = frame;
	
	self.redirectUrl = nil;
	
	if (self.server)
	{
		self.urlField.text = self.server.url;
		self.usernameField.text = self.server.username;
		self.passwordField.text = self.server.password;
	}
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // If this is a new server entry, automatically make the url field active
    if (!_server)
    {
        [self.urlField becomeFirstResponder];
    }
}

#pragma mark - Button handling

- (BOOL)checkUrl:(NSString *)url
{
	if (url.length == 0)
		return NO;
	
	if ([[url substringFromIndex:(url.length - 1)] isEqualToString:@"/"])
	{
		self.urlField.text = [url substringToIndex:([url length] - 1)];
		return YES;
	}
	
	if (url.length < 7)
	{
		self.urlField.text = [NSString stringWithFormat:@"http://%@", url];
		return YES;
	}
	else
	{
		if (![[url substringToIndex:7] isEqualToString:@"http://"])
		{
			BOOL addHttp = NO;
			if (url.length >= 8)
			{
				if (![[url substringToIndex:8] isEqualToString:@"https://"])
					addHttp = YES;
			}
			else 
			{
				addHttp = YES;
			}
			
			if (addHttp)
				self.urlField.text = [NSString stringWithFormat:@"http://%@", url];
			
			return YES;
		}
	}
	
	return YES;
}

- (BOOL)checkUsername:(NSString *)username
{
	return username.length > 0;
}

- (BOOL)checkPassword:(NSString *)password
{
	return password.length > 0;
}

- (IBAction)cancelButtonPressed:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)saveButtonPressed:(id)sender
{
    BOOL urlValid = [self checkUrl:self.urlField.text];
    BOOL usernameValid = [self checkUsername:self.usernameField.text];
    BOOL passwordValid = [self checkPassword:self.passwordField.text];
    
	if (!urlValid)
	{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self alertAction:kBadUrlTag];
        }]];
        [self presentViewController:alert animated:true completion:nil];
	}
	
	if (!usernameValid)
	{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Please enter a username" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self alertAction:kBadUserTag];
        }]];
        [self presentViewController:alert animated:true completion:nil];
	}
	
	if (!passwordValid)
	{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Please enter a password" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self alertAction:kBadPassTag];
        }]];
        [self presentViewController:alert animated:true completion:nil];
	}
	
	if (urlValid && usernameValid && passwordValid)
	{
		[LoadingScreen showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
        
        StatusLoader *loader = [[StatusLoader alloc] initWithUrl:self.urlField.text username:self.usernameField.text password:self.passwordField.text];
        loader.delegate = self;
        [loader start];
	}
}

#pragma mark - Server URL Checker delegate

- (void)loadingRedirected:(ApiLoader *)theLoader redirectUrl:(NSURL *)url
{
	NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"rest"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
	//DLog(@"redirectUrlString: %@", redirectUrlString);
	
	self.redirectUrl = [NSString stringWithString:redirectUrlString];
}

- (void)loadingFailed:(ApiLoader *)theLoader withError:(NSError *)error
{
	[LoadingScreen hideLoadingScreen];
	
	NSString *message = @"";
    NSInteger tag = 0;
    if (error.code == ISMSErrorCode_IncorrectCredentials)
    {
		message = @"Either your username or password is incorrect. Please try again";
        tag = kBadUserTag;
    }
	else
    {
		message = [NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]];
        tag = kBadUrlTag;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self alertAction:tag];
    }]];
    [self presentViewController:alert animated:true completion:nil];
}	
	
- (void)loadingFinished:(ApiLoader *)theLoader
{
    StatusLoader *statusLoader = (id)theLoader;
    
	//DLog(@"server check passed");
	[LoadingScreen hideLoadingScreen];
    
    if (self.server)
    {
        // Update existing model
        self.server.url = statusLoader.url;
        self.server.username = statusLoader.username;
        self.server.password = statusLoader.password;
        [self.server replaceModel];
    }
    else
    {
        // Create new database entry
        self.server = [[Server alloc] initWithType:ServerTypeSubsonic
                                               url:statusLoader.url
                                          username:statusLoader.username
                                       lastQueryId:@""
                                              uuid:@""
                                          password:statusLoader.password];
    }
    
    [self.delegate serverEdited:self.server];
    
    [self dismissViewControllerAnimated:YES completion:nil];

    [AppDelegate.si switchServerTo:self.server redirectUrl:self.redirectUrl];
}

#pragma mark - UITextField Delegate -

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
    
    if (textField == self.urlField)
    {
        [self.usernameField becomeFirstResponder];
    }
    else if (textField == self.usernameField)
    {
        [self.passwordField becomeFirstResponder];
    }
    else if (textField == self.passwordField)
    {
        [self saveButtonPressed:nil];
    }
    
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event];
}

#pragma mark - UIAlertView Delegate -

- (void)alertAction:(NSInteger)tag {
    UITextField *textField = nil;
    switch (tag)
    {
        case kBadUrlTag: textField = self.urlField; break;
        case kBadUserTag: textField = self.usernameField; break;
        case kBadPassTag: textField = self.passwordField; break;
        default: break;
    }
    
    [textField becomeFirstResponder];
    
    UITextRange *range = [textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument];
    [textField setSelectedTextRange:range];
}

@end
