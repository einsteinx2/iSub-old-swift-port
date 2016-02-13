//
//  SubsonicServerEditViewController.m
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SubsonicServerEditViewController.h"
#import "Imports.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"

#define kBadUrlTag 1
#define kBadUserTag 2
#define kBadPassTag 3

@interface SubsonicServerEditViewController() <UIAlertViewDelegate>
@property (nonatomic, strong) IBOutlet UITextField *urlField;
@property (nonatomic, strong) IBOutlet UITextField *usernameField;
@property (nonatomic, strong) IBOutlet UITextField *passwordField;
@property (nonatomic, strong) IBOutlet UIButton *cancelButton;
@property (nonatomic, strong) IBOutlet UIButton *saveButton;
- (IBAction) cancelButtonPressed:(id)sender;
- (IBAction) saveButtonPressed:(id)sender;
@end

@implementation SubsonicServerEditViewController

#pragma mark - Rotation

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark - Lifecycle

- (instancetype) initWithServer:(ISMSServer *)server
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
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        alert.delegate = self;
        alert.tag = kBadUrlTag;
		[alert show];
	}
	
	if (!usernameValid)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a username" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        alert.delegate = self;
        alert.tag = kBadUserTag;
		[alert show];
	}
	
	if (!passwordValid)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a password" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        alert.delegate = self;
        alert.tag = kBadPassTag;
		[alert show];
	}
	
	if (urlValid && usernameValid && passwordValid)
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
        
        ISMSStatusLoader *loader = [[ISMSStatusLoader alloc] initWithUrl:self.urlField.text username:self.usernameField.text password:self.passwordField.text];
        loader.delegate = self;
        [loader startLoad];
	}
}

#pragma mark - Server URL Checker delegate

- (void)loadingRedirected:(ISMSLoader *)theLoader redirectUrl:(NSURL *)url
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

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
	[viewObjectsS hideLoadingScreen];
	
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
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    alert.delegate = self;
    alert.tag = tag;
	[alert show];
}	
	
- (void)loadingFinished:(ISMSLoader *)theLoader
{
    ISMSStatusLoader *statusLoader = (id)theLoader;
    
	//DLog(@"server check passed");
	[viewObjectsS hideLoadingScreen];
    
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
        self.server = [[ISMSServer alloc] initWithType:ServerTypeSubsonic
                                                   url:statusLoader.url
                                              username:statusLoader.username
                                           lastQueryId:@""
                                                  uuid:@""
                                              password:statusLoader.password];
    }
    
    // TODO: Why are these notifications? And why no constants?
    [NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
    [NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    if (IS_IPAD())
        [appDelegateS.ipadRootViewController.menuViewController showHome];
    
    [appDelegateS switchServer:self.server redirectUrl:self.redirectUrl];
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

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    UITextField *textField = nil;
    switch (alertView.tag)
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
