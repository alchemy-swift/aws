import Alchemy
import AsyncHTTPClient
import SotoS3

extension Filesystem {
    /// Create a filesystem backed by an S3 or S3 compatible storage.
    public static func s3(key: String, secret: String, bucket: String, root: String = "", region: Region, endpoint: String? = nil) -> Filesystem {
        Filesystem(provider: S3Filesystem(key: key, secret: secret, bucket: bucket, root: root, region: region, endpoint: endpoint))
    }
    
    /// Create a filesystem backed by an S3 or S3 compatible storage.
    public static func s3(s3: S3, bucket: String, root: String = "") -> Filesystem {
        Filesystem(provider: S3Filesystem(s3: s3, bucket: bucket, root: root))
    }
}

/// A `FilesystemProvider` for interacting with S3 or S3 compatible storage.
private struct S3Filesystem: FilesystemProvider {
    private let s3: S3
    private let bucket: String
    let root: String
    
    init(s3: S3, bucket: String, root: String) {
        self.s3 = s3
        self.bucket = bucket
        self.root = root
    }
    
    init(key: String, secret: String, bucket: String, root: String, region: Region, endpoint: String? = nil) {
        var config = HTTPClient.Configuration()
        config.httpVersion = .http1Only
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(Loop.group), configuration: config)
        let client = AWSClient(
            credentialProvider: .static(accessKeyId: key, secretAccessKey: secret),
            httpClientProvider: .shared(httpClient)
        )
        
        self.s3 = S3(client: client, region: region, endpoint: endpoint)
        self.bucket = bucket
        self.root = root
    }
    
    // MARK: - FilesystemProvider
    
    func get(_ filepath: String) async throws -> File {
        let path = resolvedPath(filepath)
        let req = S3.GetObjectRequest(bucket: bucket, key: path)
        let res = try await s3.getObject(req)
        let size = Int(res.contentLength ?? 0)
        let content: ByteContent? = res.body?.asByteBuffer().map { .buffer($0) }
        return File(name: path, source: .filesystem(path: path), content: content, size: size)
    }
    
    func create(_ filepath: String, content: ByteContent) async throws -> File {
        let path = resolvedPath(filepath)
        let pathExtension = path.components(separatedBy: ".").last
        let contentType = pathExtension.map { ContentType(fileExtension: $0) } ?? nil
        var req: S3.PutObjectRequest
        switch content {
        case .buffer(let buffer):
            req = S3.PutObjectRequest(body: .byteBuffer(buffer), bucket: bucket, contentType: contentType?.value, key: path)
        case .stream(let stream):
            req = S3.PutObjectRequest(body: .stream { eventLoop in
                stream.read(on: eventLoop).map { output in
                    switch output {
                    case .byteBuffer(let buffer):
                        return .byteBuffer(buffer)
                    case .end:
                        return .end
                    }
                }
            }, bucket: bucket, contentType: contentType?.value, key: path)
        }
        
        _ = try await s3.putObject(req)
        return File(name: path, source: .filesystem(path: path))
    }
    
    func exists(_ filepath: String) async throws -> Bool {
        do {
            let path = resolvedPath(filepath)
            let req = S3.HeadObjectRequest(bucket: bucket, key: path)
            _ = try await s3.headObject(req)
            return true
        } catch {
            if let error = error as? S3ErrorType, error == .notFound {
                return false
            } else {
                throw error
            }
        }
    }
    
    func delete(_ filepath: String) async throws {
        let path = resolvedPath(filepath)
        let req = S3.DeleteObjectRequest(bucket: bucket, key: path)
        _ = try await s3.deleteObject(req)
    }
    
    func url(_ filepath: String) throws -> URL {
        let path = resolvedPath(filepath)
        let basePath = s3.endpoint.replacingOccurrences(of: "://", with: "://\(bucket).")
        guard let url = URL(string: "\(basePath)/\(path)") else {
            throw FileError.urlUnavailable
        }
        
        return url
    }
    
    func temporaryURL(_ filepath: String, expires: TimeAmount, headers: HTTPHeaders = [:]) async throws -> URL {
        let url = try url(filepath)
        return try await s3.signURL(url: url, httpMethod: .GET, headers: headers, expires: .seconds(10))
    }
    
    func directory(_ path: String) -> FilesystemProvider {
        let newRoot: String
        if root.isEmpty {
            newRoot = path
        } else {
            let path = root.last == "/" ? path : "/\(path)"
            newRoot = root + path
        }
        
        return S3Filesystem(s3: s3, bucket: bucket, root: newRoot)
    }
    
    private func resolvedPath(_ filePath: String) -> String {
        guard !root.isEmpty else { return filePath }
        let path = root.last == "/" ? filePath : "/\(filePath)"
        return root + path
    }
}
