import SwiftUI
import UIKit

// MARK: - Native Code Input
// Simple, clean implementation using UIKit properly without SwiftUI focus conflicts

struct NativeCodeInput: View {
    @Binding var code: String
    let onComplete: () -> Void
    
    var body: some View {
        NativeCodeTextField(
            text: $code,
            onComplete: onComplete
        )
        .frame(height: 56)
    }
}

// MARK: - UIKit Text Field Wrapper

struct NativeCodeTextField: UIViewRepresentable {
    @Binding var text: String
    let onComplete: () -> Void
    
    func makeUIView(context: Context) -> CodeInputTextField {
        let textField = CodeInputTextField()
        
        // Basic configuration
        textField.keyboardType = .numberPad
        textField.textContentType = .oneTimeCode
        textField.textAlignment = .center
        textField.font = .monospacedSystemFont(ofSize: 24, weight: .semibold)
        
        // Visual styling
        textField.backgroundColor = UIColor(DesignTokens.Colors.backgroundSecondary)
        textField.textColor = UIColor(DesignTokens.Colors.textPrimary)
        textField.tintColor = UIColor(DesignTokens.Colors.primary)
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 2
        textField.layer.borderColor = UIColor(DesignTokens.Colors.primary).cgColor
        
        // Placeholder
        textField.placeholder = "000000"
        
        // Padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
        textField.leftView = paddingView
        textField.rightView = paddingView
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        
        // Configure delegate and actions
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        
        // Set completion handler
        textField.onComplete = onComplete
        
        // Auto-focus
        DispatchQueue.main.async {
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateUIView(_ textField: CodeInputTextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            self._text = text
        }
        
        @objc func textChanged(_ textField: UITextField) {
            // Filter to only digits
            let filtered = (textField.text ?? "").filter { $0.isNumber }.prefix(6)
            let newText = String(filtered)
            
            textField.text = newText
            text = newText
            
            // Auto-complete when 6 digits entered
            if newText.count == 6, let codeField = textField as? CodeInputTextField {
                codeField.onComplete?()
            }
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // Handle paste
            if string.count > 1 {
                let digits = string.filter { $0.isNumber }
                if digits.count >= 6 {
                    let code = String(digits.prefix(6))
                    textField.text = code
                    text = code
                    textChanged(textField)
                    return false
                }
            }
            
            // Allow deletion
            if string.isEmpty {
                return true
            }
            
            // Only allow digits and limit to 6
            let currentText = textField.text ?? ""
            let isDigit = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
            return isDigit && currentText.count < 6
        }
    }
}

// MARK: - Custom UITextField

class CodeInputTextField: UITextField {
    var onComplete: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNotifications()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Removed clipboard monitoring
    }
    
    override func paste(_ sender: Any?) {
        super.paste(sender)
        
        // Trigger completion check after paste
        if let text = self.text, text.count == 6 {
            onComplete?()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Preview

struct NativeCodeInput_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            NativeCodeInput(
                code: .constant(""),
                onComplete: { print("Complete!") }
            )
            
            NativeCodeInput(
                code: .constant("123456"),
                onComplete: { print("Complete!") }
            )
        }
        .padding()
        .background(DesignTokens.Colors.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
}