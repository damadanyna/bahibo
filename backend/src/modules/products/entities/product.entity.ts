export interface SellerSnapshot {
  id: string;
  userId: string;
  name: string;
  avatarUrl: string;
  isSellerCertified: boolean;
}

export interface ProductEntity {
  id: string;
  title: string;
  description: string;
  price: number;
  currency: string;
  category: string;
  categoryId: string;
  seller: SellerSnapshot;
  images: string[];
  thumbnail: string;
  isAvailable: boolean;
  condition?: 'OCCASION' | 'RECONDITIONNE' | 'NEUF';
  hasWarranty: boolean;
  warrantyDurationValue?: number;
  warrantyDurationUnit?: 'DAYS' | 'MONTHS' | 'YEARS';
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  createdAt: string;
  city?: string;
  locationLabel?: string;
  locationLatitude?: number | null;
  locationLongitude?: number | null;
}
