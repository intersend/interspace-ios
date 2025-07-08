#!/usr/bin/env python3

import os
import re
import json

def find_all_imports(directory):
    imports = set()
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.swift'):
                filepath = os.path.join(root, file)
                with open(filepath, 'r') as f:
                    content = f.read()
                    # Find all import statements
                    import_matches = re.findall(r'^import\s+(\w+)', content, re.MULTILINE)
                    imports.update(import_matches)
    return sorted(imports)

def categorize_imports(imports):
    standard_frameworks = {
        'SwiftUI', 'UIKit', 'Foundation', 'Security', 'Combine',
        'AuthenticationServices', 'CryptoKit', 'LocalAuthentication',
        'AVFoundation', 'CoreData', 'Network', 'WebKit', 'PhotosUI',
        'UniformTypeIdentifiers', 'CoreImage'
    }
    
    third_party = []
    standard = []
    
    for imp in imports:
        if imp in standard_frameworks:
            standard.append(imp)
        else:
            third_party.append(imp)
    
    return standard, third_party

if __name__ == "__main__":
    print("Analyzing imports in Interspace project...")
    
    all_imports = find_all_imports('Interspace')
    standard, third_party = categorize_imports(all_imports)
    
    print(f"\nFound {len(all_imports)} unique imports")
    print(f"  - Standard frameworks: {len(standard)}")
    print(f"  - Third-party modules: {len(third_party)}")
    
    if third_party:
        print("\nThird-party dependencies:")
        for imp in third_party:
            print(f"  - {imp}")
    
    # Save results
    with open('import_analysis.json', 'w') as f:
        json.dump({
            'total_imports': len(all_imports),
            'standard_frameworks': standard,
            'third_party_modules': third_party
        }, f, indent=2)
    
    print("\nResults saved to: import_analysis.json")
