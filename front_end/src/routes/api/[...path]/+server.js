import { getMinioClient, getBucketName } from '$lib/config.js';
import { error } from '@sveltejs/kit';

export async function GET({ params, setHeaders, url }) {
  try {
    const { path } = params;

    if (!path) {
      throw new Error('Path parameter is undefined');
    }

    const filename = Array.isArray(path) ? path.join('/') : path;
    const minioClient = getMinioClient();
    const bucketName = getBucketName();

    // Get the object stream from MinIO
    const stream = await minioClient.getObject(bucketName, filename);

    // Get object stats to set proper headers
    const stat = await minioClient.statObject(bucketName, filename);

    // Set appropriate headers
    const headers = {
        'Content-Type': stat.metaData['content-type'],
        'Content-Length': stat.size.toString(),
        'Cache-Control': 'public, max-age=86400', // Cache for 24 hours
        'ETag': stat.etag
    };

    setHeaders(headers);

    // Return the stream as a Response
    return new Response(stream, {
      status: 200,
      headers: headers
    });

  } catch (err) {
    console.error('Error proxying file from minio:', err);
    console.error('Error details:', {
      code: err.code,
      message: err.message,
      statusCode: err.statusCode,
      amzRequestid: err.amzRequestid
    });
    throw error(404, 'Image not found');
  }
}