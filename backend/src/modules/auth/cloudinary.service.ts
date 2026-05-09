import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

type UploadImageVariant = 'avatar' | 'cover' | 'product' | 'chat-image';

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

