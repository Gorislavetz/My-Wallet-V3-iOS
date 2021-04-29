// Copyright © Blockchain Luxembourg S.A. All rights reserved.

#import "BCCreateAccountView.h"
#import "Blockchain-Swift.h"

@implementation BCCreateAccountView

-(id)init
{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    
    self = [super initWithFrame:CGRectMake(0, DEFAULT_HEADER_HEIGHT, window.frame.size.width, window.frame.size.height - DEFAULT_HEADER_HEIGHT)];
    
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        
        UILabel *labelLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, window.frame.size.width - 40, 25)];
        labelLabel.text = BC_STRING_NAME;
        labelLabel.textColor = [UIColor darkGrayColor];
        labelLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_LARGE];
        [self addSubview:labelLabel];
        
        _labelTextField = [[BCSecureTextField alloc] initWithFrame:CGRectMake(20, 95, window.frame.size.width - 40, 30)];
        _labelTextField.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:_labelTextField.font.pointSize];
        _labelTextField.borderStyle = UITextBorderStyleRoundedRect;
        _labelTextField.textColor = UIColor.gray5;
        _labelTextField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        _labelTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        _labelTextField.spellCheckingType = UITextSpellCheckingTypeNo;
        [self addSubview:_labelTextField];
        
        [_labelTextField setReturnKeyType:UIReturnKeyDone];
        _labelTextField.delegate = self;
        
        UIButton *createAccountButton = [UIButton buttonWithType:UIButtonTypeCustom];
        createAccountButton.frame = CGRectMake(0, 0, window.frame.size.width, 46);
        createAccountButton.backgroundColor = UIColor.brandSecondary;
        [createAccountButton setTitle:BC_STRING_SAVE forState:UIControlStateNormal];
        [createAccountButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        createAccountButton.titleLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_LARGE];
        
        [createAccountButton addTarget:self action:@selector(createAccountClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        _labelTextField.inputAccessoryView = createAccountButton;
    }
    
    return self;
}

# pragma mark - Button actions

- (IBAction)createAccountClicked:(id)sender
{
    if (!Reachability.hasInternetConnection) {
        [AlertViewPresenter.shared internetConnection];
        return;
    }
    // Remove whitespace
    NSString *label = [self.labelTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (label.length == 0) {
        [AlertViewPresenter.shared standardNotifyWithTitle:BC_STRING_ERROR message:BC_STRING_YOU_MUST_ENTER_A_LABEL in:nil handler:nil];
        return;
    }

    if (label.length > 17) {
        // TODO i18n
        [AlertViewPresenter.shared standardNotifyWithTitle:BC_STRING_ERROR message:BC_STRING_LABEL_MUST_HAVE_LESS_THAN_18_CHAR  in:nil handler:nil];
        return;
    }

    if (![WalletManager.sharedInstance.wallet isAccountNameValid:label]) {
        [AlertViewPresenter.shared standardErrorWithTitle:[LocalizationConstantsObjcBridge error] message:[LocalizationConstantsObjcBridge nameAlreadyInUse] in:nil handler:nil];
        [LoadingViewPresenter.shared hide];
        return;
    }

    [[ModalPresenter sharedInstance] closeModalWithTransition:kCATransitionFade];

    [WalletManager.sharedInstance.wallet createAccountWithLabel:label];
}

#pragma mark - Textfield Delegates

- (BOOL)textFieldShouldReturn:(UITextField*)aTextField
{
    [self createAccountClicked:nil];
    return YES;
}

@end
