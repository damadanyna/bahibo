import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

type DeleteCloudinaryAssetInput = {
  mediaType: 'image' | 'document';
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
  | 'chat-document';

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
      resource_type: input.mediaType === 'document' ? 'raw' : 'image',
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

