// MIT License
// 
// Copyright (c) 2017 Alexey Komnin
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "AKCurrencyTextField.h"

@interface AKCurrencyTextField ()
@property (nonatomic) BOOL editingFraction;
@end

@implementation AKCurrencyTextField

+ (NSAttributedString *)attributedStringForInteger:(int)integerPart fraction:(int)fractionPart currencyMark:(NSString *)currencyMark {
    NSString *normalized = [NSString stringWithFormat:@"%@%d.%02d", currencyMark, integerPart, fractionPart];
    NSInteger dotLocation = [normalized rangeOfString:@"."].location;
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:normalized attributes:@{ NSForegroundColorAttributeName : [UIColor whiteColor] }];
    [t addAttributes:@{ NSFontAttributeName : [self defaultIntegerPartFont] }
               range:NSMakeRange(0, dotLocation + 1)];
    [t addAttributes:@{ NSFontAttributeName : [self defaultFractionPartFont] }
               range:NSMakeRange(dotLocation + 1, 2)];
    return t;
}

+ (UIFont *)defaultIntegerPartFont {
    return [UIFont monospacedDigitSystemFontOfSize:39.f weight:UIFontWeightLight];
}
+ (UIFont *)defaultFractionPartFont {
    return [UIFont monospacedDigitSystemFontOfSize:30.f weight:UIFontWeightLight];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame currencyMark:@""];
}

- (instancetype)initWithFrame:(CGRect)frame currencyMark:(NSString *)currencyMark {
    self = [super initWithFrame:frame];
    if (self) {
        self.textColor = [UIColor whiteColor];
        self.borderStyle = UITextBorderStyleNone;
        self.keyboardType = UIKeyboardTypeDecimalPad;
        self.textAlignment = NSTextAlignmentRight;
        self.delegate = self;
        _currencyMark = currencyMark;
        _integerPartFont = [[self class] defaultIntegerPartFont];
        _fractionPartFont = [[self class] defaultFractionPartFont];
    }
    return self;
}

- (void)setText:(NSString *)text {
    NSCharacterSet *plusMinusChar = [NSCharacterSet characterSetWithCharactersInString:self.currencyMark];
    NSArray *components = [[text stringByTrimmingCharactersInSet:plusMinusChar] componentsSeparatedByString:@"."];
    
    int integerPart = [components.firstObject intValue];
    
    int fractionPart = ^{
        NSString *fractionPart = components.lastObject;
        if (fractionPart.length > 1) {
            return [[fractionPart substringToIndex:2] intValue];
        }
        else if (fractionPart.length == 1){
            return [fractionPart intValue] * 10;
        }
        else {
            return 0;
        }
    }();
    
    [self setInteger:integerPart fraction:fractionPart];
}

- (void)setInteger:(int)integerPart fraction:(int)fractionPart {
    if (fractionPart < 1) {
        fractionPart = 0;
    }
    
    NSString *normalized = (integerPart == 0 && fractionPart == 0) ? @"0.00" : [NSString stringWithFormat:@"%@%d.%02d", self.currencyMark, integerPart, fractionPart];
    NSInteger dotLocation = [normalized rangeOfString:@"."].location;
    NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:normalized];
    [t setAttributes:@{ NSFontAttributeName : self.integerPartFont }
               range:NSMakeRange(0, dotLocation + 1)];
    [t setAttributes:@{ NSFontAttributeName : self.fractionPartFont } range:NSMakeRange(dotLocation + 1, 2)];
    self.attributedText = t;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    UITextPosition *newCursorPosition = [textField positionFromPosition:textField.endOfDocument offset:-3];
    UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
    [textField setSelectedTextRange:newSelectedRange];
    self.editingFraction = NO;
}

- (void)textField:(UITextField *)textField replaceCharactersInRange:(NSRange)range withString:(NSString *)string {
    UITextPosition *beginning = textField.beginningOfDocument;
    UITextPosition *start = [textField positionFromPosition:beginning offset:range.location];
    UITextPosition *end = [textField positionFromPosition:start offset:range.length];
    UITextRange *textRange = [textField textRangeFromPosition:start toPosition:end];
    
    // now apply the text changes that were typed or pasted in to the text field
    [textField replaceRange:textRange withText:string];
    
    // now go modify the text in interesting ways doing our post processing of what was typed...
    self.text = self.text;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
    if (self.editingFraction) {
        if (![string isEqualToString:decimalSeparator]) {
            UITextPosition *locationPosition = [textField positionFromPosition:textField.beginningOfDocument offset:range.location];
            NSInteger offsetToEnd = [textField offsetFromPosition:locationPosition toPosition:textField.endOfDocument];
            if (offsetToEnd == 3) {
                self.editingFraction = NO;
                UITextPosition *newCursorPosition = [textField positionFromPosition:textField.endOfDocument offset:-3];
                UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
                [textField setSelectedTextRange:newSelectedRange];
                return NO;
            }
            
            [self textField:textField replaceCharactersInRange:range withString:string];
            NSInteger newOffsetToEnd = offsetToEnd - (NSInteger)string.length;
            if (newOffsetToEnd  < 0) {
                newOffsetToEnd = 0;
            }
            UITextPosition *newCursorPosition = [textField positionFromPosition:textField.endOfDocument offset:-newOffsetToEnd];
            UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
            [textField setSelectedTextRange:newSelectedRange];
        }
    }
    else {
        if ([string isEqualToString:decimalSeparator]) {
            self.editingFraction = YES;
            UITextPosition *newCursorPosition = [textField positionFromPosition:textField.endOfDocument offset:-2];
            UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
            [textField setSelectedTextRange:newSelectedRange];
        }
        else {
            [self textField:textField replaceCharactersInRange:range withString:string];
            UITextPosition *newCursorPosition = [textField positionFromPosition:textField.endOfDocument offset:-3];
            UITextRange *newSelectedRange = [textField textRangeFromPosition:newCursorPosition toPosition:newCursorPosition];
            [textField setSelectedTextRange:newSelectedRange];
        }
    }
    
    return NO;
}

@end

