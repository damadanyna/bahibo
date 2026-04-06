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
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  createdAt: string;
}
