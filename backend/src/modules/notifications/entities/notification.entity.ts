export interface NotificationEntity {
  id: string;
  type: string;
  title: string;
  body: string;
  isRead: boolean;
  createdAt: string;
  likeCount?: number;
  commentCount?: number;
  sellerProfile?: {
    id: string;
    studioName: string;
  } | null;
  seller: {
    id: string;
    name: string;
    avatarUrl: string;
  };
  product: {
    id: string;
    title: string;
    imageUrl: string;
  } | null;
  actors?: Array<{
    id: string;
    name: string;
    avatarUrl: string;
    timeLabel: string;
  }>;
}
