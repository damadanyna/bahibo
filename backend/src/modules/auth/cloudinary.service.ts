import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

type DeleteCloudinaryAssetInput = {
  mediaType: 'image' | 'document' | 'video';
  publicId?: string | null;
  storageKey?: string | null;
  publicUrl?: string | null;
};

type ListCloudinaryAssetsInput = {
  mediaType: 'image' | 'document';
  maxResults?: number;
  nextCursor?: string | null;
};

type CloudinaryListedAsset = {
  publicId: string;
  secureUrl: string | null;
  createdAt: string | null;
  bytes: number | null;
  resourceType: string | null;
};

type CloudinaryListedAssetsPage = {
  assets: CloudinaryListedAsset[];
  nextCursor: string | null;
};

type UploadImageVariant =
  | 'avatar'
  | 'cover'
  | 'product'
  | 'chat-image'
  | 'chat-document'
  | 'story';

@Injectable()
export class CloudinaryService {
  private static readonly chatImagePreviewTransformation = [
    {
      width: 1400,
      height: 1400,
      crop: 'fill',
      gravity: 'auto',
      fetch_format: 'auto',
      quality: 'auto:good',
    },
  ] as const;

  private static readonly chatImageThumbnailTransformation = [
    {
      width: 560,
      height: 560,
      crop: 'fill',
      gravity: 'auto',
      fetch_format: 'auto',
      quality: 'auto:eco',
    },
  ] as const;

  /**
   * Playback rendition of a story video: 720p H.264/AAC MP4. Phones record
   * 1080p-4K at bitrates that make the viewer buffer, and their `moov`
   * atom often sits at the end of the file, which forces a full download
   * before the first frame; Cloudinary's MP4 output is faststart.
   * Requested eagerly (in the background) at upload time and rebuilt with
   * the exact same object by [buildStoryVideoPlaybackUrl], so both URLs
   * resolve to the same derived asset.
   */
  private static readonly storyVideoTransformation = [
    {
      width: 720,
      height: 1280,
      crop: 'limit',
      quality: 'auto:good',
      video_codec: 'h264',
      audio_codec: 'aac',
    },
  ] as const;

  private static readonly storyVideoPosterTransformation = [
    {
      width: 720,
      height: 1280,
      crop: 'limit',
      start_offset: '0',
      quality: 'auto:eco',
    },
  ] as const;

  /** Renditions generated in the background right after a video upload. */
  private static readonly storyVideoEagerTransformations = [
    { ...CloudinaryService.storyVideoTransformation[0], format: 'mp4' },
    { ...CloudinaryService.storyVideoPosterTransformation[0], format: 'jpg' },
  ] as const;

  /**
   * Same encoding as the SDK's `build_eager` (not exposed to TypeScript):
   * one transformation string per rendition, `/format` appended, joined
   * by `|`. Used to sign a direct upload with exactly the `eager` value
   * the phone will send.
   */
  private static buildEagerParam(
    transformations: ReadonlyArray<Record<string, string | number>>,
  ) {
    return transformations
      .map((transformation) => {
        const { format, ...options } = transformation;
        const value = cloudinary.utils.generate_transformation_string({ ...options });
        return format ? `${value}/${format}` : value;
      })
      .join('|');
  }

  constructor(private readonly configService: ConfigService) {
    const cloudName = this.configService.get<string>('CLOUDINARY_CLOUD_NAME');
    const apiKey = this.configService.get<string>('CLOUDINARY_API_KEY');
    const apiSecret = this.configService.get<string>('CLOUDINARY_API_SECRET');

    if (cloudName && apiKey && apiSecret) {
      cloudinary.config({
        cloud_name: cloudName,
        api_key: apiKey,
        api_secret: apiSecret,
        secure: true,
      });
    }
  }

  isConfigured() {
    return Boolean(
      this.configService.get<string>('CLOUDINARY_CLOUD_NAME') &&
        this.configService.get<string>('CLOUDINARY_API_KEY') &&
        this.configService.get<string>('CLOUDINARY_API_SECRET'),
    );
  }

  createDirectChatImageUploadSignature(identifier: string) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const cloudName = this.configService.get<string>('CLOUDINARY_CLOUD_NAME')!;
    const apiKey = this.configService.get<string>('CLOUDINARY_API_KEY')!;
    const apiSecret = this.configService.get<string>('CLOUDINARY_API_SECRET')!;
    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    const timestamp = Math.floor(Date.now() / 1000);
    const folder = this.resolveFolder('chat-image');
    const publicId = `${sanitizedIdentifier}-chat-image-${Date.now()}`;
    const signature = cloudinary.utils.api_sign_request(
      {
        folder,
        overwrite: 'true',
        public_id: publicId,
        timestamp,
      },
      apiSecret,
    );

    return {
      cloudName,
      apiKey,
      timestamp,
      folder,
      publicId,
      overwrite: true,
      signature,
    };
  }

  createDirectChatDocumentUploadSignature(identifier: string) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const cloudName = this.configService.get<string>('CLOUDINARY_CLOUD_NAME')!;
    const apiKey = this.configService.get<string>('CLOUDINARY_API_KEY')!;
    const apiSecret = this.configService.get<string>('CLOUDINARY_API_SECRET')!;
    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    const timestamp = Math.floor(Date.now() / 1000);
    const folder = this.resolveFolder('chat-document');
    const publicId = `${sanitizedIdentifier}-chat-document-${Date.now()}`;
    const signature = cloudinary.utils.api_sign_request(
      {
        folder,
        overwrite: 'true',
        public_id: publicId,
        timestamp,
      },
      apiSecret,
    );

    return {
      cloudName,
      apiKey,
      timestamp,
      folder,
      publicId,
      overwrite: true,
      signature,
    };
  }

  async uploadProfileImage(file: Express.Multer.File, phoneE164: string) {
    return this.uploadUserImage(file, phoneE164, 'avatar');
  }

  async uploadUserImage(
    file: Express.Multer.File,
    identifier: string,
    variant: UploadImageVariant,
  ) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    const folder = this.resolveFolder(variant);
    const uploadResult = await new Promise<UploadApiResponse>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder,
          public_id: `${sanitizedIdentifier}-${variant}-${Date.now()}`,
          resource_type: 'image',
          overwrite: true,
        },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload failed'));
            return;
          }

          resolve(result);
        },
      );

      stream.end(file.buffer);
    });

    const transformedImageUrl = cloudinary.url(uploadResult.public_id, {
      secure: true,
      version: uploadResult.version,
      transformation: this.buildTransformation(variant),
    });

    return {
      originalUrl: uploadResult.secure_url,
      imageUrl: transformedImageUrl,
      publicId: uploadResult.public_id,
    };
  }

  async uploadProductImage(file: Express.Multer.File, identifier: string) {
    return this.uploadUserImage(file, identifier, 'product');
  }

  async uploadStoryImage(file: Express.Multer.File, identifier: string) {
    return this.uploadUserImage(file, identifier, 'story');
  }

  /**
   * Story videos are stored as recorded: a synchronous transcode would
   * stretch the upload request past reverse-proxy timeouts. The playback
   * rendition and the JPEG poster are instead requested as eager
   * transformations generated in the background once the upload is done
   * (`eager_async`), so they are usually ready before the first viewer.
   * Also returns the duration for the client timer.
   */
  async uploadStoryVideo(file: Express.Multer.File, identifier: string) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    const uploadResult = await new Promise<UploadApiResponse>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'BANAY/stories',
          public_id: `${sanitizedIdentifier}-story-video-${Date.now()}`,
          resource_type: 'video',
          overwrite: true,
          eager: [...CloudinaryService.storyVideoEagerTransformations],
          eager_async: true,
        },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload failed'));
            return;
          }

          resolve(result);
        },
      );

      stream.end(file.buffer);
    });

    return {
      originalUrl: uploadResult.secure_url,
      videoUrl: uploadResult.secure_url,
      thumbnailUrl: this.buildStoryVideoPosterUrl(
        uploadResult.public_id,
        uploadResult.version,
      ),
      publicId: uploadResult.public_id,
      durationSeconds: CloudinaryService.normalizeDuration(
        (uploadResult as Record<string, unknown>).duration,
      ),
    };
  }

  // ---------------------------------------------------------------------
  // Direct (phone → Cloudinary) story uploads
  // ---------------------------------------------------------------------

  /**
   * Signed parameters for a story media uploaded straight from the phone,
   * so the file no longer transits through this server (twice the
   * transfer time on a slow uplink). Every signed value is returned
   * verbatim in `fields`: the phone forwards them as-is next to `file`.
   * A video also carries the eager renditions of [uploadStoryVideo].
   */
  createDirectStoryUploadSignature(
    identifier: string,
    resourceType: 'image' | 'video',
  ) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const cloudName = this.configService.get<string>('CLOUDINARY_CLOUD_NAME')!;
    const apiKey = this.configService.get<string>('CLOUDINARY_API_KEY')!;
    const apiSecret = this.configService.get<string>('CLOUDINARY_API_SECRET')!;
    const folder = this.resolveFolder('story');
    const publicId = `${this.storyPublicIdPrefix(identifier, resourceType)}${Date.now()}`;
    const timestamp = Math.floor(Date.now() / 1000);
    const paramsToSign: Record<string, string> = {
      folder,
      overwrite: 'true',
      public_id: publicId,
      timestamp: `${timestamp}`,
    };
    if (resourceType === 'video') {
      paramsToSign.eager = CloudinaryService.buildEagerParam(
        CloudinaryService.storyVideoEagerTransformations,
      );
      paramsToSign.eager_async = 'true';
    }
    const signature = cloudinary.utils.api_sign_request(paramsToSign, apiSecret);

    return {
      cloudName,
      resourceType,
      /** Public id as Cloudinary will report it (folder included). */
      publicId: `${folder}/${publicId}`,
      fields: { ...paramsToSign, api_key: apiKey, signature },
    };
  }

  /** Whether [publicId] was issued by [createDirectStoryUploadSignature] for this user. */
  isDirectStoryPublicIdOf(
    publicId: string,
    identifier: string,
    resourceType: 'image' | 'video',
  ) {
    const prefix = `${this.resolveFolder('story')}/${this.storyPublicIdPrefix(
      identifier,
      resourceType,
    )}`;
    return publicId.startsWith(prefix) && /^\d+$/.test(publicId.slice(prefix.length));
  }

  /**
   * Checks the `signature` Cloudinary returns in an upload response
   * (SHA-1 of `public_id` + `version` + the account secret): proves the
   * asset was uploaded to this account, whoever hands the id back.
   */
  verifyUploadResponseSignature(
    publicId: string,
    version: number | string,
    signature: string,
  ) {
    if (!this.isConfigured()) {
      return false;
    }
    const apiSecret = this.configService.get<string>('CLOUDINARY_API_SECRET')!;
    const expected = cloudinary.utils.api_sign_request(
      { public_id: publicId, version: `${version}` },
      apiSecret,
    );
    return expected === signature.trim();
  }

  /** Metadata of an uploaded asset, read back from Cloudinary (Admin API). */
  async describeAsset(publicId: string, resourceType: 'image' | 'video') {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const resource: Record<string, unknown> = await cloudinary.api.resource(publicId, {
      resource_type: resourceType,
    });

    return {
      version: typeof resource.version === 'number' ? resource.version : null,
      format: typeof resource.format === 'string' ? resource.format : null,
      bytes: typeof resource.bytes === 'number' ? resource.bytes : null,
      durationSeconds: CloudinaryService.normalizeDuration(resource.duration),
    };
  }

  /** Delivery URL of a story photo, same sizing as [uploadStoryImage]. */
  buildStoryImageUrl(publicId: string, version: number) {
    return cloudinary.url(publicId, {
      secure: true,
      version,
      transformation: this.buildTransformation('story'),
    });
  }

  /** Source (as uploaded) and poster URLs of a story video. */
  buildStoryVideoUrls(publicId: string, version: number, format: string | null) {
    return {
      videoUrl: cloudinary.url(publicId, {
        secure: true,
        resource_type: 'video',
        version,
        format: format ?? 'mp4',
      }),
      thumbnailUrl: this.buildStoryVideoPosterUrl(publicId, version),
    };
  }

  private buildStoryVideoPosterUrl(publicId: string, version: number) {
    return cloudinary.url(publicId, {
      secure: true,
      resource_type: 'video',
      version,
      format: 'jpg',
      transformation: [...CloudinaryService.storyVideoPosterTransformation],
    });
  }

  private storyPublicIdPrefix(identifier: string, resourceType: 'image' | 'video') {
    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    return `${sanitizedIdentifier}-story-${resourceType}-`;
  }

  private static normalizeDuration(rawDuration: unknown) {
    return typeof rawDuration === 'number' && Number.isFinite(rawDuration)
      ? Math.round(rawDuration)
      : null;
  }

  /**
   * Delivery URL of the optimized story rendition (see
   * `storyVideoTransformation`). Stories published before the rendition
   * existed get it generated by Cloudinary on first request. Falls back to
   * the stored URL when the public id cannot be resolved.
   */
  buildStoryVideoPlaybackUrl(input: {
    publicId?: string | null;
    publicUrl?: string | null;
  }) {
    const fallbackUrl = input.publicUrl?.trim() ?? '';
    if (!this.isConfigured()) {
      return fallbackUrl;
    }

    const publicId = this.resolvePublicId(input.publicId, null, input.publicUrl);
    if (!publicId) {
      return fallbackUrl;
    }

    return cloudinary.url(publicId, {
      secure: true,
      resource_type: 'video',
      format: 'mp4',
      transformation: [...CloudinaryService.storyVideoTransformation],
    });
  }

  async uploadChatImage(file: Express.Multer.File, identifier: string) {
    const uploadResult = await this.uploadUserImage(file, identifier, 'chat-image');

    return {
      ...uploadResult,
      previewUrl: this.buildChatImagePreviewUrl(uploadResult.publicId),
      thumbnailUrl: this.buildChatImageThumbnailUrl(uploadResult.publicId),
    };
  }

  async uploadChatDocument(file: Express.Multer.File, identifier: string) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const sanitizedIdentifier = identifier.replace(/[^a-zA-Z0-9]/g, '');
    const uploadResult = await new Promise<UploadApiResponse>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'BANAY/chat-documents',
          public_id: `${sanitizedIdentifier}-chat-document-${Date.now()}`,
          resource_type: 'raw',
          overwrite: true,
          use_filename: true,
        },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload failed'));
            return;
          }

          resolve(result);
        },
      );

      stream.end(file.buffer);
    });

    return {
      originalUrl: uploadResult.secure_url,
      fileUrl: uploadResult.secure_url,
      publicId: uploadResult.public_id,
    };
  }

  async deleteAsset(input: DeleteCloudinaryAssetInput) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const publicId = this.resolvePublicId(
      input.publicId,
      input.storageKey,
      input.publicUrl,
    );
    if (!publicId) {
      return { result: 'skipped' as const, publicId: null };
    }

    const result = await cloudinary.uploader.destroy(publicId, {
      resource_type:
        input.mediaType === 'document'
          ? 'raw'
          : input.mediaType === 'video'
            ? 'video'
            : 'image',
      invalidate: true,
    });

    return {
      result: result.result,
      publicId,
    };
  }

  async listChatAssets(input: ListCloudinaryAssetsInput) {
    if (!this.isConfigured()) {
      throw new BadRequestException('Cloudinary is not configured');
    }

    const resourceType = input.mediaType === 'document' ? 'raw' : 'image';
    const prefix =
      input.mediaType === 'document' ? 'BANAY/chat-documents' : 'BANAY/chat-images';
    const response = await cloudinary.api.resources({
      type: 'upload',
      resource_type: resourceType,
      prefix,
      max_results: Math.min(Math.max(input.maxResults ?? 100, 1), 500),
      next_cursor: input.nextCursor?.trim() || undefined,
    });

    const resources = Array.isArray(response.resources) ? response.resources : [];
    return {
      assets: resources.map((resource: any) => ({
        publicId: typeof resource.public_id === 'string' ? resource.public_id : '',
        secureUrl: typeof resource.secure_url === 'string' ? resource.secure_url : null,
        createdAt: typeof resource.created_at === 'string' ? resource.created_at : null,
        bytes: typeof resource.bytes === 'number' ? resource.bytes : null,
        resourceType:
          typeof resource.resource_type === 'string' ? resource.resource_type : null,
      })) satisfies CloudinaryListedAsset[],
      nextCursor:
        typeof response.next_cursor === 'string' ? response.next_cursor : null,
    } satisfies CloudinaryListedAssetsPage;
  }

  private resolveFolder(variant: UploadImageVariant) {
    if (variant === 'cover') {
      return 'BANAY/profile-covers';
    }

    if (variant === 'product') {
      return 'BANAY/products';
    }

    if (variant === 'chat-image') {
      return 'BANAY/chat-images';
    }

    if (variant === 'story') {
      return 'BANAY/stories';
    }

    if (variant === 'chat-document') {
      return 'BANAY/chat-documents';
    }

    return 'BANAY/profile-avatars';
  }

  buildChatImagePreviewUrl(publicIdOrUrl: string) {
    return this.buildChatImageVariantUrl(
      publicIdOrUrl,
      CloudinaryService.chatImagePreviewTransformation,
    );
  }

  buildChatImageThumbnailUrl(publicIdOrUrl: string) {
    return this.buildChatImageVariantUrl(
      publicIdOrUrl,
      CloudinaryService.chatImageThumbnailTransformation,
    );
  }

  buildChatImageVariants(input: { publicId?: string | null; publicUrl?: string | null }) {
    const publicId = input.publicId?.trim() ?? '';
    const publicUrl = input.publicUrl?.trim() ?? '';
    const source = publicId.length > 0 ? publicId : publicUrl;

    if (source.length === 0) {
      return {
        previewUrl: null,
        thumbnailUrl: null,
      };
    }

    return {
      previewUrl: this.buildChatImagePreviewUrl(source),
      thumbnailUrl: this.buildChatImageThumbnailUrl(source),
    };
  }

  private buildChatImageVariantUrl(
    publicIdOrUrl: string,
    transformation: readonly Record<string, string | number>[],
  ) {
    const normalized = publicIdOrUrl.trim();
    if (normalized.length === 0) {
      return '';
    }

    if (normalized.includes('res.cloudinary.com')) {
      const uploadMarker = '/upload/';
      const uploadIndex = normalized.indexOf(uploadMarker);
      if (uploadIndex < 0) {
        return normalized;
      }

      const prefix = normalized.substring(0, uploadIndex + uploadMarker.length);
      const suffix = normalized.substring(uploadIndex + uploadMarker.length);
      const suffixWithoutTransformation = suffix.replace(/^(?:[^/]+\/)+?(?=v\d+\/|[^/]+$)/, '');
      const transformationValue = transformation
        .map((step) =>
          Object.entries(step)
            .map(([key, value]) => `${key}_${value}`)
            .join(','),
        )
        .join('/');

      return `${prefix}${transformationValue}/${suffixWithoutTransformation}`;
    }

    if (!this.isConfigured()) {
      return normalized;
    }

    return cloudinary.url(normalized, {
      secure: true,
      transformation,
    });
  }

  private resolvePublicId(
    publicId?: string | null,
    storageKey?: string | null,
    publicUrl?: string | null,
  ) {
    const normalizedPublicId = publicId?.trim() ?? '';
    if (normalizedPublicId.length > 0) {
      return normalizedPublicId;
    }

    const normalizedStorageKey = storageKey?.trim() ?? '';
    if (normalizedStorageKey.length > 0) {
      return normalizedStorageKey;
    }

    const normalizedPublicUrl = publicUrl?.trim() ?? '';
    if (normalizedPublicUrl.length === 0) {
      return null;
    }

    return this.extractPublicIdFromUrl(normalizedPublicUrl);
  }

  private extractPublicIdFromUrl(publicUrl: string) {
    if (!publicUrl.includes('res.cloudinary.com')) {
      return null;
    }

    const uploadMarker = '/upload/';
    const uploadIndex = publicUrl.indexOf(uploadMarker);
    if (uploadIndex < 0) {
      return null;
    }

    const suffix = publicUrl.substring(uploadIndex + uploadMarker.length);
    const suffixWithoutVersion = suffix.replace(/^(?:[^/]+\/)+?(?=v\d+\/|[^/]+$)/, '');
    const versionPrefixMatch = suffixWithoutVersion.match(/^v\d+\/(.+)$/);
    const assetPath = versionPrefixMatch?.[1] ?? suffixWithoutVersion;
    const lastDotIndex = assetPath.lastIndexOf('.');

    return lastDotIndex > assetPath.lastIndexOf('/')
      ? assetPath.substring(0, lastDotIndex)
      : assetPath;
  }

  private buildTransformation(variant: UploadImageVariant) {
    if (variant === 'cover') {
      return [
        {
          width: 1600,
          height: 900,
          crop: 'fill',
          gravity: 'auto',
          fetch_format: 'auto',
          quality: 'auto:good',
        },
      ];
    }

    if (variant === 'product') {
      return [
        {
          width: 1400,
          height: 1400,
          crop: 'fill',
          gravity: 'auto',
          fetch_format: 'auto',
          quality: 'auto:good',
        },
      ];
    }

    if (variant === 'chat-image') {
      return [...CloudinaryService.chatImagePreviewTransformation];
    }

    if (variant === 'story') {
      // Full-screen portrait viewer: cap the size but keep the aspect
      // ratio (no crop), the client letterboxes on a dark background.
      return [
        {
          width: 1080,
          height: 1920,
          crop: 'limit',
          fetch_format: 'auto',
          quality: 'auto:good',
        },
      ];
    }

    return [
      {
        width: 512,
        height: 512,
        crop: 'fill',
        gravity: 'auto',
        fetch_format: 'auto',
        quality: 'auto:good',
      },
    ];
  }
}

