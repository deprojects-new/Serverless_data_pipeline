# Serverless Data Pipeline - Production Grade Architecture

## Problem Statement

Modern web applications generate massive volumes of log data that require real-time processing to extract actionable business intelligence. Organizations need a serverless data pipeline(event-driven) that can automatically process web logs, transform them into business metrics, and provide insights for decision-making while maintaining data quality and operational reliability.

This project addresses these challenges by implementing a production-grade serverless data pipeline using AWS services that automatically processes web application logs, transforms them through multiple data quality layers, and generates business-ready analytics datasets.

## Architecture Overview

The pipeline implements a **Medallion Architecture** with three distinct data layers:

- **Bronze Layer**: Raw JSON web logs with minimal processing
- **Silver Layer**: Cleaned, validated, and partitioned Parquet data
- **Gold Layer**: Business-ready aggregated metrics and KPIs

The architecture is fully serverless, event-driven, and designed for production scalability with comprehensive monitoring and error handling.

## Architectural Diagram

```mermaid
graph TB
    %% External Data Sources
    subgraph "Data Sources"
        A[Web Application Logs]
        [Sample Data Generator]
    end

    %% S3 Data Lake
    subgraph "S3 Data Lake - assignment5-data-lake"
        subgraph "Bronze Layer"
            C[bronze/raw_logs.json]
        end
        
        subgraph "Silver Layer"
            D[silver/year=2024/month=01/day=15/]
            E[silver/year=2024/month=01/day=16/]
        end
        
        subgraph "Gold Layer"
            F[gold/daily_metrics/]
            G[gold/session_metrics/]
        end
        
        subgraph "Supporting"
            H[glue_scripts/]
            
        end
    end

    %% AWS Services
    subgraph "AWS Lambda"
        J[Lambda Function<br/>S3 Event Trigger]
    end

    subgraph "AWS Step Functions"
        K[State Machine<br/>Pipeline Orchestration]
        K1[SetExecutionContext]
        K2[StartBronzeToSilverJob]
        K3[WaitForJobCompletion]
        K4[StartCrawlerBackground]
        K5[StartSilverToGoldJob]
    end

    subgraph "AWS Glue"
        L[Bronze→Silver ETL Job<br/>Data Cleaning & Validation]
        M[Silver→Gold ETL Job<br/>Business Aggregations]
        N[Silver Crawler<br/>Schema Discovery]
        O[Glue Data Catalog<br/>Metadata Management]
    end

    subgraph "AWS IAM"
        P[Lambda Execution Role]
        Q[Glue Execution Role]
        R[Step Functions Role]
        S[Data Engineers Group]
    end

    subgraph "Amazon CloudWatch"
        T[Logs]
        U[Metrics]
        V[Alarms]
    end

    %% Data Flow Connections
    A --> C
    B --> C
    C --> J
    J --> K
    K --> K1
    K1 --> K2
    K2 --> L
    L --> D
    K2 --> K3
    K3 --> K4
    K4 --> N
    N --> O
    K4 --> K5
    K5 --> M
    D --> M
    M --> F
    M --> G

    %% IAM Connections
    J -.-> P
    L -.-> Q
    M -.-> Q
    N -.-> Q
    K -.-> R
    S -.-> C
    S -.-> D
    S -.-> F

    %% Monitoring Connections
    J -.-> T
    L -.-> T
    M -.-> T
    K -.-> T
    J -.-> U
    L -.-> U
    M -.-> U
    K -.-> U
    U -.-> V

    %% Styling
    classDef s3Layer fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef awsService fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef iamService fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef monitoringService fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef dataSource fill:#fff8e1,stroke:#f57f17,stroke-width:2px

    class C,D,E,F,G,H,I s3Layer
    class J,K,L,M,N,O awsService
    class P,Q,R,S iamService
    class T,U,V monitoringService
    class A,B dataSource
```

### Architecture Components

**Data Flow**:
1. **Ingestion**: Web logs or sample data uploaded to S3 Bronze layer
2. **Trigger**: S3 event triggers Lambda function
3. **Orchestration**: Step Functions coordinates the entire pipeline
4. **ETL Processing**: Glue jobs transform data between layers
5. **Schema Management**: Crawler updates Data Catalog metadata
6. **Output**: Business-ready metrics in Gold layer

**Service Integration**:
- **Event-Driven**: S3 → Lambda → Step Functions → Glue
- **Serverless**: All compute resources scale automatically
- **Monitored**: CloudWatch provides comprehensive observability
- **Secured**: IAM roles enforce least-privilege access

**Data Layers**:
- **Bronze**: Raw, unprocessed data (JSON format)
- **Silver**: Cleaned, validated, partitioned data (Parquet format)
- **Gold**: Business aggregations and KPIs (Parquet format)

## AWS Services and Their Roles

### Core Services

**Amazon S3 (Simple Storage Service)**
- **Purpose**: Data lake storage across all three layers
- **Configuration**: Versioning enabled, AES256 encryption, lifecycle policies for cost optimization
- **Business Value**: Provides scalable, durable, and cost-effective storage for data at rest

**AWS Lambda**
- **Purpose**: Event trigger that initiates the data pipeline
- **Trigger**: S3 object creation events in the bronze layer
- **Business Value**: Eliminates server management overhead and provides automatic scaling

**AWS Step Functions**
- **Purpose**: Orchestrates the entire ETL workflow
- **States**: Coordinates Glue jobs and crawler execution with error handling
- **Business Value**: Provides visual workflow management and built-in retry logic

**AWS Glue**
- **Purpose**: Serverless ETL processing and data catalog management
- **Components**: 
  - ETL Jobs: Transform data between layers
  - Crawler: Automatically discovers and catalogs data schemas
  - Data Catalog: Centralized metadata repository
- **Business Value**: Eliminates infrastructure management for data processing

**Amazon CloudWatch**
- **Purpose**: Monitoring, logging, and alerting
- **Components**: Logs, metrics, alarms
- **Business Value**: Provides operational visibility and proactive issue detection

### Supporting Services

**AWS IAM (Identity and Access Management)**
- **Purpose**: Security and access control
- **Components**: Roles, policies, and user management
- **Business Value**: Ensures least-privilege access and compliance

## Data Flow and Processing Logic

### 1. Data Ingestion (Bronze Layer)
**Trigger**: S3 object creation in `s3://assignment5-data-lake/bronze/`
**Process**: Lambda function receives S3 event and triggers Step Functions execution
**Data Format**: Raw JSON web logs with fields like event_id, event_ts, session_id, method, path, status, etc.

### 2. Bronze to Silver Transformation
**ETL Script**: `src/glue_scripts/bronze_silver.py`
**Processing Logic**:
- **Schema Validation**: Ensures all expected fields are present
- **Data Type Casting**: Converts string values to appropriate data types (int, long)
- **Data Quality Checks**: Validates HTTP status codes, methods, and performance metrics
- **PII Removal**: Masks or removes sensitive client information
- **Partitioning**: Organizes data by year/month/day for efficient querying
- **Output**: Clean Parquet files in `s3://assignment5-data-lake/silver/`



### 3. Silver to Gold Transformation
**ETL Script**: `src/glue_scripts/silver_gold.py`
**Processing Logic**:
- **Incremental Processing**: Uses Glue Job Bookmarks with smart fallback to timestamp-based filtering
- **Business Aggregations**: Calculates daily metrics and session analytics
- **KPI Generation**: Computes error rates, success rates, and performance indicators
- **Deduplication**: Prevents duplicate records in fallback scenarios
- **Output**: Business-ready metrics in `s3://assignment5-data-lake/gold/`



## Infrastructure as Code (Terraform)

### Module Structure

**S3 Module** (`terraform/modules/s3/`)
- Data lake bucket with versioning and encryption
- Lifecycle policies for cost optimization
- S3 event notifications for Lambda triggers
- Public access blocking for security

**IAM Module** (`terraform/modules/iam/`)
- Service roles for Lambda, Glue, and Step Functions
- User policies for the data engineers group
- Least-privilege access principles
- Cross-service permissions management

**Glue Module** (`terraform/modules/glue/`)
- ETL job definitions and configurations
- Crawler setup for automatic schema discovery
- Database and table metadata management
- Job monitoring and alerting

**Step Functions Module** (`terraform/modules/step_functions/`)
- State machine definition for workflow orchestration
- Error handling and retry logic
- Execution monitoring and alerting
- Non-blocking crawler integration

**Lambda Module** (`terraform/modules/lambda/`)
- Event trigger function configuration
- Environment variables and permissions
- CloudWatch logging setup
- S3 event source mapping

### Key Infrastructure Decisions

**Serverless Architecture**: Eliminates server management overhead and provides automatic scaling
**Event-Driven Processing**: Ensures real-time data processing without polling
**Modular Design**: Enables independent development and deployment of components
**Security-First**: Implements least-privilege access and encryption at rest

## Security and Access Control

### IAM Roles and Policies

**Lambda Execution Role**
- Permissions: S3 read access, Step Functions execution, CloudWatch logging
- Scope: Limited to assignment5-data-lake bucket and state machine

**Glue Execution Role**
- Permissions: S3 read/write access, Glue Data Catalog operations, CloudWatch logging
- Scope: Limited to project-specific resources

**Step Functions Execution Role**
- Permissions: Glue job and crawler management, CloudWatch logging
- Scope: Limited to orchestration activities

**Data Engineers Group**
- Permissions: Read access to all data layers, monitoring access, limited write access
- Scope: Business user access for analysis and monitoring

### Security Features

- **Encryption**: AES256 server-side encryption for all data at rest
- **Access Control**: Public access blocking on assignment5-data-lake bucket
- **Audit Trail**: Comprehensive CloudWatch logging for all operations
- **Least Privilege**: Minimal required permissions for each service

## Monitoring and Observability

### CloudWatch Alarms

**Pipeline Health Monitoring**
- Step Functions execution failures
- Glue job failures and timeouts
- Crawler execution monitoring

**Performance Monitoring**
- ETL job duration tracking
- Data volume processing metrics
- Error rate monitoring
- Response time tracking

### Logging Strategy

**Structured Logging**: All components use structured logging with consistent formats
**Log Levels**: INFO, WARNING, ERROR, DEBUG for appropriate detail levels
**Correlation IDs**: Track requests across all pipeline components
**Business Metrics**: Log key business indicators and data quality metrics

## Data Quality and Governance

### Data Validation

**Schema Validation**: Ensures data structure consistency
**Data Type Validation**: Validates and casts data types appropriately
**Business Rule Validation**: Applies domain-specific validation rules
**Null Value Handling**: Proper handling of missing data

### Data Lineage

**Processing Timestamps**: Tracks when data was processed
**Source Tracking**: Maintains references to original data sources
**Transformation Tracking**: Logs all data transformations applied
**Quality Metrics**: Tracks data quality indicators

## Business Value and Use Cases

### End Users

**Data Analysts**: Access clean, aggregated data for business intelligence
**Business Stakeholders**: Review KPIs and performance metrics
**Development Teams**: Analyze application usage patterns

### Business Applications

**Performance Monitoring**: Track application response times and error rates
**User Behavior Analysis**: Understand user session patterns and preferences
**Capacity Planning**: Analyze traffic patterns for infrastructure planning
**Revenue Impact**: Correlate technical metrics with business outcomes

### Key Performance Indicators

- **Error Rate**: Percentage of failed requests
- **Success Rate**: Percentage of successful requests
- **Average Response Time**: Mean response time across all requests
- **Data Volume**: Total data processed per time period
- **Processing Efficiency**: Time to process data from bronze to gold

## Operational Considerations

### Scalability

**Automatic Scaling**: All services scale automatically based on demand
**Partitioning Strategy**: Data partitioned by date for efficient querying
**Lifecycle Management**: Automatic data archival and deletion policies
**Cost Optimization**: Storage class transitions based on access patterns

### Reliability

**Error Handling**: Comprehensive error handling at all pipeline stages
**Retry Logic**: Automatic retries for transient failures
**Data Consistency**: Ensures data integrity across all layers
**Backup Strategy**: S3 versioning for data protection

### Maintenance

**Infrastructure as Code**: All infrastructure managed through Terraform
**Automated Testing**: Basic CI/CD pipeline for code quality assurance(Rookies)
**Monitoring**: Proactive monitoring and alerting
**Documentation**: Comprehensive documentation for all components

## Deployment and CI/CD

### GitHub Actions Workflows

**Terraform Workflow** (`.github/workflows/terraform.yml`)
- Infrastructure validation and planning
- Automated testing of Terraform configurations
- Environment-specific deployments

**Code Quality Workflow** (`.github/workflows/code.yml`)
- Code formatting and linting
- Unit testing and integration testing
- Security scanning and vulnerability assessment

### Environment Management

**Development Environment**: Testing and development activities
**Production Environment**: Live data processing and business operations
**Environment Isolation**: Separate resources and configurations per environment

## Cost Optimization

### Storage Optimization

**Lifecycle Policies**: Automatic data archival to cheaper storage classes
**Compression**: Parquet format for efficient storage and querying
**Partitioning**: Efficient data organization for cost-effective querying
**Cleanup Policies**: Automatic deletion of temporary and obsolete data

### Compute Optimization

**Serverless Architecture**: Pay-per-use pricing model
**Job Optimization**: Efficient ETL job configurations
**Crawler Scheduling**: Optimized crawler frequency for cost and performance
**Resource Allocation**: Right-sized resources for workload requirements

## Future Enhancements

### Advanced Analytics

**Machine Learning Integration**: Predictive analytics and anomaly detection
**Real-time Processing**: Stream processing for immediate insights
**Advanced Aggregations**: Complex business metrics and KPIs
**Data Visualization**: Interactive dashboards and reporting

### Operational Improvements

**Data Quality Monitoring**: Automated data quality assessment
**Performance Optimization**: Enhanced ETL job performance
**Security Enhancements**: Advanced security and compliance features
**Integration Capabilities**: Additional data source integrations

## Conclusion

This serverless data pipeline provides a production-grade solution for processing web application logs and generating business intelligence. The architecture is designed for scalability, reliability, and cost efficiency while maintaining high data quality and security standards. The modular design enables easy maintenance and future enhancements, making it suitable for enterprise-level data processing requirements.

The pipeline successfully transforms raw web logs into actionable business metrics, providing valuable insights for decision-making and operational monitoring. The serverless approach eliminates infrastructure management overhead while providing automatic scaling and high availability.
