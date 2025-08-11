import * as Minio from 'minio';

let minioClient = null;
let bucketName = null;
let dbClientEndpoint = null;

function checkEnv() {
    let missingEnvs = [];
    // The hostname without the protocol or the port (i.e. localhost)
    if (!process.env.S3_ENDPOINT) {
        missingEnvs.push("S3_ENDPOINT");
    }

    if (!process.env.S3_ENDPOINT_PORT) {
        missingEnvs.push("S3_ENDPOINT_PORT");
    }

    if (!process.env.S3_ACCESS_KEY) {
        missingEnvs.push("S3_ACCESS_KEY");
    }

    if (!process.env.S3_SECRET_KEY) {
        missingEnvs.push("S3_SECRET_KEY");
    }

    if (!process.env.S3_BUCKET_NAME) {
        missingEnvs.push("S3_BUCKET_NAME");
    }

    // This needs to be the full URL, including the protocol and port (i.e. http://localhost:8080)
    if (!process.env.DB_CLIENT_ENDPOINT) {
        missingEnvs.push("DB_CLIENT_ENDPOINT");
    }

    // Docker Compose does NOT use 
    if (!process.env.USE_SSL) {
        missingEnvs.push("USE_SSL");
    }

    if (missingEnvs.length > 0) {
        console.error(`ERROR the following environment variables are required but not set: ${missingEnvs.join(", ")}`);
        process.exit(1);
    }
}

function getMinioClient() {
    if (!minioClient) {
        checkEnv();
        minioClient = new Minio.Client({
            endPoint: process.env.S3_ENDPOINT,
            port: process.env.S3_ENDPOINT_PORT,
            useSSL: process.env.USE_SSL === 'true', // Minio in docker DOES NOT use SSL; however minio-tenant in Kubernetes DOES
            accessKey: process.env.S3_ACCESS_KEY,
            secretKey: process.env.S3_SECRET_KEY
        });
    }

    return minioClient;
}

function getDBClientEndpoint() {
    if (!dbClientEndpoint) {
        checkEnv();
        dbClientEndpoint = process.env.DB_CLIENT_ENDPOINT;
    }

    return dbClientEndpoint;
}

function getBucketName() {
    if (!bucketName) {
        checkEnv();
        bucketName = process.env.S3_BUCKET_NAME;
    }

    return bucketName;
}

export { getMinioClient, getBucketName, getDBClientEndpoint};