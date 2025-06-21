import SwiftUI
import UIKit

// MARK: - Verification Code Field

struct VerificationCodeField: View {
    @Binding var code: String
    let onComplete: () -> Void
    
    @State private var codeDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var pasteboardHasCode = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<6) { index in
                    SingleDigitField(
                        digit: $codeDigits[index],
                        index: index,
                        focusedIndex: $focusedIndex,
                        onBackspace: handleBackspace,
                        onPaste: handlePaste
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                checkClipboard()
            }
            
            // Quick actions
            HStack(spacing: 12) {
                // Paste button if clipboard has content
                if pasteboardHasCode {
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 14))
                            Text("Paste code")
                                .font(.caption)
                        }
                        .foregroundColor(DesignTokens.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.Colors.primary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DesignTokens.Colors.primary.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }
                
                // Clear button if any digits entered
                if codeDigits.contains(where: { !$0.isEmpty }) {
                    Button(action: clearCode) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14))
                            Text("Clear")
                                .font(.caption)
                        }
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DesignTokens.Colors.textSecondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DesignTokens.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: pasteboardHasCode)
            .animation(.easeInOut(duration: 0.2), value: codeDigits)
        }
        .onChange(of: codeDigits) { oldDigits, newDigits in
            let newCode = newDigits.joined()
            code = newCode
            
            // Auto-submit when all 6 digits are entered
            if newCode.count == 6 && newDigits.allSatisfy({ !$0.isEmpty }) {
                onComplete()
            }
        }
        .onChange(of: code) { oldCode, newCode in
            // Sync external code changes to individual digits
            if newCode.count <= 6 && newCode.allSatisfy({ $0.isNumber }) {
                for index in 0..<6 {
                    if index < newCode.count {
                        let digitIndex = newCode.index(newCode.startIndex, offsetBy: index)
                        codeDigits[index] = String(newCode[digitIndex])
                    } else {
                        codeDigits[index] = ""
                    }
                }
            }
        }
        .onAppear {
            checkClipboard()
            focusedIndex = 0
            
            // Check for email app verification codes
            checkForEmailVerificationCode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkClipboard()
            checkForEmailVerificationCode()
        }
    }
    
    private func handleBackspace(at index: Int) {
        if index > 0 {
            codeDigits[index - 1] = ""
            focusedIndex = index - 1
        }
    }
    
    private func handlePaste(_ pastedString: String) {
        var extractedCode = ""
        
        // First try to extract a 6-digit code using regex patterns
        let patterns = [
            "\\b(\\d{6})\\b", // 6 digits surrounded by word boundaries
            "code.*?(\\d{6})", // "code" followed by 6 digits
            "(\\d{6}).*?code", // 6 digits followed by "code"
            ":\\s*(\\d{6})", // colon followed by 6 digits
            "(\\d{6})\\s*is", // 6 digits followed by "is"
            "verification.*?(\\d{6})", // "verification" followed by 6 digits
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let match = regex.firstMatch(in: pastedString, options: [], range: NSRange(location: 0, length: pastedString.utf16.count)) {
                    // Find the first capture group that contains 6 digits
                    for i in 1..<match.numberOfRanges {
                        if let range = Range(match.range(at: i), in: pastedString) {
                            let matchedString = String(pastedString[range])
                            if matchedString.filter({ $0.isNumber }).count == 6 {
                                extractedCode = matchedString
                                break
                            }
                        }
                    }
                    
                    // If no capture group, check the whole match
                    if extractedCode.isEmpty, let range = Range(match.range, in: pastedString) {
                        let matchedString = String(pastedString[range])
                        let digits = matchedString.filter { $0.isNumber }
                        if digits.count == 6 {
                            extractedCode = digits
                        }
                    }
                    
                    if !extractedCode.isEmpty {
                        break
                    }
                }
            }
        }
        
        // Fallback: just extract the first 6 digits
        if extractedCode.isEmpty {
            extractedCode = String(pastedString.filter { $0.isNumber }.prefix(6))
        }
        
        // Fill in the digits
        for (index, digit) in extractedCode.enumerated() {
            if index < 6 {
                codeDigits[index] = String(digit)
            }
        }
        
        // Focus the next empty field or the last field
        if let firstEmptyIndex = codeDigits.firstIndex(where: { $0.isEmpty }) {
            focusedIndex = firstEmptyIndex
        } else {
            focusedIndex = 5
        }
    }
    
    private func checkClipboard() {
        let pasteboard = UIPasteboard.general
        if let string = pasteboard.string {
            // Check if it contains a 6-digit code
            let digits = string.filter { $0.isNumber }
            pasteboardHasCode = digits.count >= 6
            
            // Also check for common verification code patterns
            if !pasteboardHasCode {
                // Check for patterns like "Your code is: 123456" or "123456 is your verification code"
                let patterns = [
                    "\\b\\d{6}\\b", // 6 digits surrounded by word boundaries
                    "code.*?(\\d{6})", // "code" followed by 6 digits
                    "(\\d{6}).*?code" // 6 digits followed by "code"
                ]
                
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count))
                        if !matches.isEmpty {
                            pasteboardHasCode = true
                            break
                        }
                    }
                }
            }
        } else {
            pasteboardHasCode = false
        }
    }
    
    private func pasteFromClipboard() {
        let pasteboard = UIPasteboard.general
        if let string = pasteboard.string {
            handlePaste(string)
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func clearCode() {
        codeDigits = Array(repeating: "", count: 6)
        focusedIndex = 0
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func checkForEmailVerificationCode() {
        // iOS 12+ can detect verification codes from Messages and Mail
        // This is handled automatically by the system when using
        // textContentType(.oneTimeCode) on the text fields
        
        // Additionally check if the app was launched from a universal link
        // or if there's a code in the pasteboard when coming from email
        checkClipboard()
        
        // Also listen for the system's auto-fill suggestions
        if #available(iOS 16.0, *) {
            // iOS 16+ has improved code detection from Mail app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkClipboard()
            }
        }
    }
}

// MARK: - Single Digit Field

struct SingleDigitField: View {
    @Binding var digit: String
    let index: Int
    @FocusState.Binding var focusedIndex: Int?
    let onBackspace: (Int) -> Void
    let onPaste: (String) -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focusedIndex == index ? DesignTokens.Colors.primary : DesignTokens.Colors.borderPrimary,
                            lineWidth: focusedIndex == index ? 2 : 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focusedIndex == index)
            
            if digit.isEmpty {
                Text(" ")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(digit)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Invisible text field for input
            DigitTextField(
                text: $digit,
                index: index,
                focusedIndex: $focusedIndex,
                onBackspace: onBackspace,
                onPaste: onPaste
            )
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundColor(.clear)
            .multilineTextAlignment(.center)
            .focused($focusedIndex, equals: index)
            .opacity(0.01) // Nearly invisible but still interactive
        }
        .frame(width: 48, height: 56)
    }
}

// MARK: - Custom UITextField Wrapper

struct DigitTextField: UIViewRepresentable {
    @Binding var text: String
    let index: Int
    @FocusState.Binding var focusedIndex: Int?
    let onBackspace: (Int) -> Void
    let onPaste: (String) -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let textField = BackspaceTextField()
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode // Enable auto-fill from SMS and email apps
        textField.font = .systemFont(ofSize: 24, weight: .semibold)
        textField.tintColor = UIColor(DesignTokens.Colors.primary)
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        
        // Important: Set text color explicitly to ensure visibility
        textField.textColor = UIColor(DesignTokens.Colors.textPrimary)
        
        // Enable user interaction explicitly
        textField.isUserInteractionEnabled = true
        
        // Set up custom backspace handling
        textField.onBackspace = { [weak textField] in
            if textField?.text?.isEmpty ?? true {
                onBackspace(index)
            }
        }
        
        // Add paste action to context menu
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // Only update text if it's different to avoid cursor issues
        if uiView.text != text {
            uiView.text = text
        }
        
        // Update focus state
        if focusedIndex == index && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if focusedIndex != index && uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        let parent: DigitTextField
        
        init(_ parent: DigitTextField) {
            self.parent = parent
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Handle paste or auto-fill from email/SMS
            if string.count > 1 {
                parent.onPaste(string)
                return false
            }
            
            // Handle backspace
            if string.isEmpty {
                // If the field is already empty, move to previous field
                if textField.text?.isEmpty ?? true {
                    parent.onBackspace(parent.index)
                    return false
                }
                // Clear the current field
                parent.text = ""
                return true
            }
            
            // Only allow single digit numbers
            guard string.count == 1, string.allSatisfy({ $0.isNumber }) else {
                return false
            }
            
            // Replace existing text with new digit
            parent.text = string
            textField.text = string
            
            // Move to next field after a brief delay to ensure the text is displayed
            if parent.index < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.parent.focusedIndex = self.parent.index + 1
                }
            } else if parent.index == 5 {
                // Dismiss keyboard on last field
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.resignFirstResponder()
                }
            }
            
            // Return false since we're manually setting the text
            return false
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            // Update the binding when text changes
            parent.text = textField.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.focusedIndex = parent.index
        }
    }
}

// MARK: - Custom UITextField with Backspace Detection

class BackspaceTextField: UITextField {
    var onBackspace: (() -> Void)?
    
    override func deleteBackward() {
        if text?.isEmpty ?? true {
            onBackspace?()
        }
        super.deleteBackward()
    }
    
    // Override to ensure the keyboard shows properly
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    // Handle paste from the edit menu
    override func paste(_ sender: Any?) {
        if let pasteboardString = UIPasteboard.general.string {
            // Trigger the delegate method with the pasted string
            if let delegate = self.delegate,
               delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:))) {
                _ = delegate.textField?(self, shouldChangeCharactersIn: NSRange(location: 0, length: self.text?.count ?? 0), replacementString: pasteboardString)
            }
        }
    }
}


// MARK: - Preview

struct VerificationCodeField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            VerificationCodeField(
                code: .constant(""),
                onComplete: {}
            )
            
            VerificationCodeField(
                code: .constant("123"),
                onComplete: {}
            )
            
        }
        .padding()
        .background(DesignTokens.Colors.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
}