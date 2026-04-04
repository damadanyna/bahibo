export interface SellerSnapshot {
  id: string;
  name: string;
  avatarUrl: string;
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
  createdAt: string;
}
