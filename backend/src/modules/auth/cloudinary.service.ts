import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

type UploadImageVariant = 'avatar' | 'cover' | 'product';

@Injectable()
export class CloudinaryService {
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
    const folder =
      variant === 'cover'
        ? 'BANAY/profile-covers'
        : variant === 'product'
        ? 'BANAY/products'
        : 'BANAY/profile-avatars';
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

