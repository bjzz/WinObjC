//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#include "Starboard.h"
#include "UIKit/UIView.h"
#include "UIKit/UIControl.h"
#include "Foundation/NSString.h"
#include "CoreGraphics/CGAffineTransform.h"
#include "CoreGraphics/CGContext.h"
#include "UIKit/UIColor.h"
#include "UIKit/UIImage.h"
#include "UIKit/UIActionSheet.h"

@implementation UIActionSheet {
    id _delegate;
    NSString *_title;
    UILabel *_titleLabel;
    UIView* _darkView;
    CGRect _hidePosition;
    int _dismissIndex;
    BOOL _delegateSupportsDidDismiss;

    ActionSheetButton _buttons[16];
    int          _numButtons;

    float        _totalHeight;
    int          _cancelButtonIndex, _cancelCustomIndex;
    int          _destructiveIndex;
    int          _otherButtonIndex;
}
    static int addButton(UIActionSheet* self, id text)
    {
        CGRect frame;

        frame.origin.x = 10.0f;
        frame.origin.y = self->_totalHeight;
        frame.size.width = 300.0f;
        frame.size.height = 30.0f;

        self->_totalHeight += 40.0f;

        id buttonBackground = [[UIImage imageNamed:@"/img/blackbutton-pressed@2x.png"] stretchableImageWithLeftCapWidth:9 topCapHeight:0];
        id buttonPressed = [[UIImage imageNamed:@"/img/blackbutton-normal@2x.png"] stretchableImageWithLeftCapWidth:9 topCapHeight:0];

        id ret = [[UIButton alloc] initWithFrame:frame];
        [ret setTitle:text forState:0];
        [ret setTitleColor:[UIColor whiteColor] forState:0];
        [ret setBackgroundImage:buttonBackground forState:0];
        [ret setBackgroundImage:buttonPressed forState:1];
        [ret setTag:self->_numButtons];
        [ret addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];

        self->_buttons[self->_numButtons].button = ret;
        self->_buttons[self->_numButtons].buttonPos = frame;

        return self->_numButtons ++;
    }

    /* annotate with type */ -(id) init {
        _cancelButtonIndex = _cancelCustomIndex = -1;
        _otherButtonIndex = -1;
        _destructiveIndex = -1;

        id image;
        image = [[UIImage imageNamed:@"/img/alertsheet-background@2x.png"] stretchableImageWithLeftCapWidth:70 topCapHeight:18];

        UIImageSetLayerContents([self layer], image);

        _totalHeight += 20.0f;

        EbrOnShowKeyboardInternal();

        return self;
    }

    /* annotate with type */ -(id) initWithTitle:(id)title delegate:(id)delegate cancelButtonTitle:(id)cancelButtonTitle destructiveButtonTitle:(id)destructiveButtonTitle otherButtonTitles:(id)otherButtonTitles , ...{
        va_list pReader; va_start(pReader, otherButtonTitles);
        [self init];

        _totalHeight = 0.0f;

        [self setDelegate:delegate];
        _title = title;
        _cancelButtonIndex = _cancelCustomIndex = -1;
        _otherButtonIndex = -1;
        _destructiveIndex = -1;

        if ( _title != nil ) {
            CGRect frame;

            frame.origin.x = 10.0f;
            frame.origin.y = 0.0f;
            frame.size.width = 300.0f;
            frame.size.height = 50.0f;

            _titleLabel = [[UILabel alloc] initWithFrame:frame];
            [_titleLabel setText:_title];
            [_titleLabel setTextColor:[UIColor whiteColor]];
            [_titleLabel setBackgroundColor:nil];

            _totalHeight += 50.0f;
        } else {
            _totalHeight += 20.0f;
        }

        if ( destructiveButtonTitle != nil ) {
            _destructiveIndex = addButton(self, destructiveButtonTitle);
        }

        id otherButtonTitle = otherButtonTitles; // va_arg(pReader, id);
        while ( otherButtonTitle != nil ) {
            int idx = addButton(self, otherButtonTitle);
            if ( _otherButtonIndex == -1 ) {
                _otherButtonIndex = idx;
            }

            otherButtonTitle = va_arg(pReader, id);
        }

        va_end(pReader);

        if ( cancelButtonTitle != nil ) {
            _totalHeight += 10.0f;
            _cancelButtonIndex = _cancelCustomIndex = addButton(self, cancelButtonTitle);
        }

        if ( cancelButtonTitle != nil ) {
            [_buttons[_cancelButtonIndex].button sendControlEventsOnBack:UIControlEventTouchUpInside];
        } else if ( destructiveButtonTitle != nil ) {
            [_buttons[_destructiveIndex].button sendControlEventsOnBack:UIControlEventTouchUpInside];
        }

        _totalHeight += 10.0f;

        if ( _titleLabel != nil ) {
            [self addSubview:_titleLabel];
        }

        for ( int i = 0; i < _numButtons; i ++ ) {
            [self addSubview:_buttons[i].button];
        }

        return self;
    }

    /* annotate with type */ -(id) showInView:(id)view {
        if ( [_delegate respondsToSelector:@selector(willPresentActionSheet:)] ) {
            [_delegate willPresentActionSheet:self];
        }

        CGRect frame;
        frame = [view bounds];

        UIWindow* popupWindow = [[UIApplication sharedApplication] _popupWindow];

        CGPoint pt1, pt2;

        pt1.x = frame.origin.x;
        pt1.y = frame.origin.y + frame.size.height;
        pt2.x = frame.origin.x + frame.size.width;
        pt2.y = frame.origin.y + frame.size.height;
        pt1 = [view convertPoint:pt1 toView:popupWindow];
        pt2 = [view convertPoint:pt2 toView:popupWindow];

        CGRect fullScreen;
        fullScreen = [[UIScreen mainScreen] applicationFrame];
        _darkView = [[UIView alloc] initWithFrame:fullScreen];
        [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
        [_darkView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_darkView setBackgroundColor:[UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f]];
        [_darkView setAlpha:0.0f];

        if ( pt1.y == pt2.y ) {
            frame.origin = pt1;
            frame.size.height = 0;
            frame.size.width = pt2.x - pt1.x;

            [self setFrame:frame];

            [popupWindow addSubview:_darkView];
            [popupWindow addSubview:self];

            [UIView beginAnimations:@"ShowAlert" context:nil];
            [UIView setAnimationDuration:0.25f];
            [_darkView setAlpha:1.0f];

            memcpy(&_hidePosition, &frame, sizeof(CGRect));
            frame.origin.y -= _totalHeight;
            frame.size.height = _totalHeight;
            [self setFrame:frame];
            [UIView commitAnimations];
        } else {
            CGAffineTransform trans;

            trans = CGAffineTransformMakeRotation(kPi / 2);
            [self setTransform:trans];

            //  Rotate
            frame.origin = pt1;
            frame.size.width = 0;
            frame.size.height = pt2.y - pt1.y;

            [self setFrame:frame];

            [popupWindow addSubview:_darkView];
            [popupWindow addSubview:self];

            [UIView beginAnimations:@"ShowAlert" context:nil];
            [UIView setAnimationDuration:0.25f];
            [_darkView setAlpha:1.0f];

            memcpy(&_hidePosition, &frame, sizeof(CGRect));
            frame.size.width = _totalHeight;
            [self setFrame:frame];
            [UIView commitAnimations];
        }

        if ( [_delegate respondsToSelector:@selector(didPresentActionSheet:)] ) {
            [_delegate didPresentActionSheet:self];
        }

        return self;
    }

    -(void) showFromToolbar:(id)toolbar {
        [self showInView:[toolbar superview]];
    }

    -(void) showFromTabBar:(id)tabbar {
        [self showInView:[tabbar window]];
    }

    -(void) showFromBarButtonItem:(id)item animated:(BOOL)animated {
        [self showInView:[[[item _getView] superview] superview]];
    }

    -(void) /* use typed version */ layoutSubviews {
        CGRect bounds;

        bounds = [self bounds];

        for ( int i = 0; i < _numButtons; i ++ ) {
            CGRect frame = _buttons[i].buttonPos;

            frame.size.width = bounds.size.width - frame.origin.x * 2.0f;
            [_buttons[i].button setFrame:frame];
        }
    }

    /* annotate with type */ -(void) setTitle:(NSString*)title {
        _title = [title copy];
        // TODO: Questionable return type and/or value here
    }

    -(id) /* use typed version */ title {
        return _title;
    }

    /* annotate with type */ -(id) addButtonWithTitle:(NSString*)title {
        int idx = addButton(self, title);
        if ( _otherButtonIndex == -1 ) {
            _otherButtonIndex = idx;
        }
        [self addSubview:_buttons[idx].button];
        [self setNeedsLayout];

        return self;
    }

    /* annotate with type */ -(void) setDestructiveButtonIndex:(int)destructiveIndex {
        _destructiveIndex = destructiveIndex;
    }

    /* annotate with type */ -(void) setDelegate:(id)delegate {
        _delegate = delegate;
        _delegateSupportsDidDismiss = [_delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)];
    }

    /* annotate with type */ -(id) delegate {
        return _delegate;
    }

    /* annotate with type */ -(void) setActionSheetStyle:(UIActionSheetStyle)style {

    }

    /* annotate with type */ -(id) _didHideAlert {
        if ( _dismissIndex != -1 ) {
            if ( _delegateSupportsDidDismiss ) {
                [_delegate actionSheet:self didDismissWithButtonIndex:_dismissIndex];
            }
        }
        [_darkView removeFromSuperview];
        [self removeFromSuperview];

        return 0;
    }

    static void dismissView(UIActionSheet* self, int index)
    {
        [UIView beginAnimations:@"HideAlert" context:nil];
        [UIView setAnimationDuration:0.25f];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(_didHideAlert)];
        self->_dismissIndex = index;
        [self->_darkView setAlpha:0.0f];
        CGRect frame = self->_hidePosition;
        [self setFrame:frame];
        [UIView commitAnimations];

        EbrOnHideKeyboardInternal();
    }

    -(void) buttonClicked:(id)button {
        [[self retain] autorelease];
        [_delegate retain];
        [_delegate autorelease];
        int index = [button tag];

        if ( index == _cancelButtonIndex ) index = _cancelCustomIndex;

        if ( [_delegate respondsToSelector:@selector(actionSheet:clickedButtonAtIndex:)] ) {
            [_delegate actionSheet:self clickedButtonAtIndex:index];
        } else if ( [_delegate respondsToSelector:@selector(alertSheet:buttonClicked:)] ) {
            [_delegate alertSheet:self buttonClicked:index];
        }

        if ( [_delegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)] ) {
            [_delegate actionSheet:self willDismissWithButtonIndex:index];
        }

        dismissView(self, index);
    }

    /* annotate with type */ -(void) touchesEnded:(id)touches withEvent:(id)event {
        /*
        [[self retain] autorelease];
        [_delegate retain];
        [_delegate autorelease];
        int index = -1;

        if ( [_delegate respondsToSelector:@selector(actionSheet:willDismissWithButtonIndex:)] ) {
            [_delegate actionSheet:self willDismissWithButtonIndex:index];
        }

        dismissView(self, index);

        if ( [_delegate respondsToSelector:@selector(actionSheet:didDismissWithButtonIndex:)] ) {
            [_delegate actionSheet:self didDismissWithButtonIndex:index];
        }
        */
    }

    /* annotate with type */ -(id) buttonTitleAtIndex:(int)index {
        assert(_buttons[index].button != nil);

        return [_buttons[index].button currentTitle];
    }

    -(int) numberOfButtons {
        return _numButtons;
    }

    -(int) cancelButtonIndex {
        return _cancelCustomIndex;
    }

    /* annotate with type */ -(void) setCancelButtonIndex:(NSInteger)index {
        _cancelCustomIndex = index;
        [_buttons[_cancelButtonIndex].button sendControlEventsOnBack:UIControlEventTouchUpInside];
    }

    -(int) firstOtherButtonIndex {
        return _otherButtonIndex;
    }

    -(id) /* use typed version */ dismiss {
        dismissView(self, -1);

        return self;
    }

    -(BOOL) isVisible {
        return [self superview] != nil;
    }

    /* annotate with type */ -(id) dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated {
        EbrDebugLog("dismissWithClicked .. fire an event?\n");
        return self;
    }

        
        
    
@end

