#!/usr/bin/env python3
"""
Simple test script to validate Lambda function structure
"""

import json
import sys
import os

# Add src to path
sys.path.append('src/lambda_code')

def test_import():
    """Test that we can import the Lambda function"""
    try:
        from lambda_function import lambda_handler
        print("✅ Successfully imported lambda_handler function")
        return True
    except ImportError as e:
        print(f"❌ Failed to import lambda_handler: {e}")
        return False

def test_function_signature():
    """Test that the function has the correct signature"""
    try:
        from lambda_function import lambda_handler
        import inspect
        
        # Check function signature
        sig = inspect.signature(lambda_handler)
        params = list(sig.parameters.keys())
        
        if 'event' in params and 'context' in params:
            print("✅ Function has correct signature (event, context)")
            return True
        else:
            print(f"❌ Function has wrong signature: {params}")
            return False
    except Exception as e:
        print(f"❌ Error checking function signature: {e}")
        return False

def test_syntax():
    """Test that the code has valid Python syntax"""
    try:
        with open('src/lambda_code/lambda_function.py', 'r') as f:
            code = f.read()
        
        # Try to compile the code
        compile(code, 'lambda_function.py', 'exec')
        print("✅ Lambda function has valid Python syntax")
        return True
    except SyntaxError as e:
        print(f"❌ Syntax error in lambda_function.py: {e}")
        return False
    except Exception as e:
        print(f"❌ Error checking syntax: {e}")
        return False

def test_required_modules():
    """Test that required modules are imported"""
    try:
        with open('src/lambda_code/lambda_function.py', 'r') as f:
            code = f.read()
        
        required_imports = ['json', 'boto3', 'logging', 'os', 'datetime']
        missing_imports = []
        
        for module in required_imports:
            if f'import {module}' not in code and f'from {module}' not in code:
                missing_imports.append(module)
        
        if missing_imports:
            print(f"❌ Missing required imports: {missing_imports}")
            return False
        else:
            print("✅ All required modules are imported")
            return True
    except Exception as e:
        print(f"❌ Error checking imports: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Starting simple Lambda function tests...")
    print("=" * 50)
    
    tests = [
        test_import,
        test_function_signature,
        test_syntax,
        test_required_modules
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print("=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All basic tests passed! Lambda function structure is correct.")
    else:
        print("❌ Some tests failed. Please fix issues before deployment.")
        sys.exit(1)
