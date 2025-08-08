#!/usr/bin/env python3
"""
Mock test for Lambda function - mocks AWS services
"""

import json
import sys
import os
from unittest.mock import Mock, patch

# Add lambda_code to path
sys.path.append('../lambda_code')

def test_lambda_function():
    """Test the Lambda function with mocked AWS services"""
    
    # Load test event
    with open('test_event.json', 'r') as f:
        event = json.load(f)
    
    print("Testing Lambda function with mocked AWS services...")
    print(f"Event: {json.dumps(event, indent=2)}")
    print("-" * 50)
    
    # Mock the specific clients that are created at module level
    with patch('lambda_function.glue_client') as mock_glue, patch('lambda_function.s3_client') as mock_s3:
        # Mock Glue client methods
        mock_glue.start_crawler.return_value = {'ResponseMetadata': {'HTTPStatusCode': 200}}
        mock_glue.get_crawler.return_value = {
            'Crawler': {
                'Name': 'assignment5-crawler',
                'State': 'READY'
            }
        }
        mock_glue.start_job_run.return_value = {'JobRunId': 'test-job-run-id'}
        
        # Mock S3 client methods
        mock_s3.head_object.return_value = {'ContentLength': 1024}
        
        try:
            # Import and test the Lambda function
            from lambda_function import lambda_handler
            
            # Create mock context
            context = Mock()
            context.function_name = "test-lambda"
            context.function_version = "1"
            context.invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test-lambda"
            context.memory_limit_in_mb = 128
            context.remaining_time_in_millis = lambda: 300000
            
            # Call the Lambda function
            result = lambda_handler(event, context)
            
            print("Lambda function executed successfully!")
            print(f"Response: {json.dumps(result, indent=2)}")
            
            # Verify the function called the expected AWS services
            mock_glue.start_crawler.assert_called_once_with(Name='assignment5-crawler')
            mock_glue.get_crawler.assert_called()
            mock_glue.start_job_run.assert_called_once_with(JobName='assignment5-etl-job')
            
            print("All AWS service calls verified!")
            return True
            
        except Exception as e:
            print(f"Lambda function failed: {str(e)}")
            return False

def test_error_handling():
    """Test error handling scenarios"""
    
    print("\nTesting error handling...")
    
    # Test with invalid event
    invalid_event = {"invalid": "event"}
    
    with patch('lambda_function.glue_client') as mock_glue:
        # Mock Glue client methods
        mock_glue.start_crawler.return_value = {'ResponseMetadata': {'HTTPStatusCode': 200}}
        mock_glue.get_crawler.return_value = {
            'Crawler': {
                'Name': 'assignment5-crawler',
                'State': 'READY'
            }
        }
        
        try:
            from lambda_function import lambda_handler
            
            context = Mock()
            context.function_name = "test-lambda"
            context.function_version = "1"
            context.invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test-lambda"
            context.memory_limit_in_mb = 128
            context.remaining_time_in_millis = lambda: 300000
            
            result = lambda_handler(invalid_event, context)
            print("Should have failed with invalid event")
            return False
        except Exception as e:
            print(f"Correctly handled invalid event: {str(e)}")
            return True

def test_import():
    """Test that we can import the Lambda function"""
    try:
        from lambda_function import lambda_handler
        print("Successfully imported lambda_handler function")
        return True
    except ImportError as e:
        print(f"Failed to import lambda_handler: {e}")
        return False

def test_syntax():
    """Test that the code has valid Python syntax"""
    try:
        with open('../lambda_code/lambda_function.py', 'r') as f:
            code = f.read()
        
        # Try to compile the code
        compile(code, 'lambda_function.py', 'exec')
        print("Lambda function has valid Python syntax")
        return True
    except SyntaxError as e:
        print(f"Syntax error in lambda_function.py: {e}")
        return False
    except Exception as e:
        print(f"Error checking syntax: {e}")
        return False

if __name__ == "__main__":
    print("Starting mock Lambda function tests...")
    print("=" * 50)
    
    tests = [
        test_import,
        test_syntax,
        test_lambda_function,
        test_error_handling
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
        print()
    
    print("=" * 50)
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("All tests passed! Lambda function is ready for deployment.")
    else:
        print("Some tests failed. Please fix issues before deployment.")
        sys.exit(1)
