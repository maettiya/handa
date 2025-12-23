# Disable checksum for Cloudflare R2 compatibility
# R2 doesn't support the newer S3 checksum algorithms

Rails.application.config.after_initialize do
  if defined?(ActiveStorage::Service::S3Service)
    ActiveStorage::Service::S3Service.class_eval do
      def upload(key, io, checksum: nil, **options)
        instrument :upload, key: key, checksum: checksum do
          @client.put_object(
            bucket: @bucket.name,
            key: key,
            body: io,
            **options
          )
        end
      end
    end
  end
end
