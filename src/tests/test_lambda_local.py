#!/usr/bin/env python3
"""
Local test script for Lambda function
This simulates the Lambda environment and tests the function logic
"""

import json
import sys
import os
import boto3
from unittest.mock import Mock, patch

# Add src to path so we can import the Lambda function
sys.path.append('../lambda_code')

# Import the Lambda function
from lambda_function import lambda_handler

def create_mock_context():
    """Create a mock Lambda context"""
    context = Mock()
    context.function_name = "test-lambda"
    context.function_version = "1"
    context.invoked_function_arn = "arn:aws:lambda:us-east-2:123456789012:function:test-lambda"
    context.memory_limit_in_mb = 128
    context.remaining_time_in_millis = lambda: 300000  # 5 minutes
    return context

def test_lambda_function():
    """Test the Lambda function with mock AWS services"""
    
    # Load test event
    with open('test_event.json', 'r') as f:
        event = json.load(f)
    
    # Create mock context
    context = create_mock_context()
    
    print("Testing Lambda function locally...")
    print(f"Event: {json.dumps(event, indent=2)}")
    print("-" * 50)
    
    # Mock AWS services
    with patch('boto3.client') as mock_boto3:
        # Mock Glue client
        mock_glue = Mock()
        mock_glue.start_crawler.return_value = {'ResponseMetadata': {'HTTPStatusCode': 200}}
        mock_glue.get_crawler.return_value = {
            'Crawler': {
                'Name': 'assignment5-crawler',
                'State': 'READY'
            }
        }
        mock_glue.start_job_run.return_value = {'JobRunId': 'test-job-run-id'}
        
        # Mock S3 client
        mock_s3 = Mock()
        mock_s3.head_object.return_value = {'ContentLength': 1024}
        
        # Configure boto3 to return our mocks
        mock_boto3.side_effect = lambda service: mock_glue if service == 'glue' else mock_s3
        
        try:
            # Call the Lambda function
            result = lambda_handler(event, context)
            
            print("Lambda function executed successfully!")
            print(f"Response: {json.dumps(result, indent=2)}")
            
            # Verify the function called the expected AWS services
            mock_glue.start_crawler.assert_called_once_with(Name='assignment5-crawler')
            mock_glue.get_crawler.assert_called()
            mock_glue.start_job_run.assert_called_once_with(JobName='assignment5-etl-job')
            
            print("All AWS service calls verified!")
            
        except Exception as e:
            print(f"Lambda function failed: {str(e)}")
            return False
    
    return True

def test_error_handling():
    """Test error handling scenarios"""
    
    print("\n Testing error handling...")
    
    # Test with invalid event
    invalid_event = {"invalid": "event"}
    context = create_mock_context()
    
    with patch('boto3.client') as mock_boto3:
        mock_glue = Mock()
        mock_boto3.return_value = mock_glue
        
        try:
            result = lambda_handler(invalid_event, context)
            print("Should have failed with invalid event")
            return False
        except Exception as e:
            print(f"Correctly handled invalid event: {str(e)}")
    
    return True

if __name__ == "__main__":
    print("Starting Lambda function local testing...")
    print("=" * 50)
    
    # Test 1: Normal execution
    success1 = test_lambda_function()
    
    # Test 2: Error handling
    success2 = test_error_handling()
    
    print("=" * 50)
    if success1 and success2:
        print("All tests passed! Lambda function is ready for deployment.")
    else:
        print("Some tests failed. Please fix issues before deployment.")
        sys.exit(1)
