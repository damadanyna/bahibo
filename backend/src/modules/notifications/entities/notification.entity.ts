export interface NotificationEntity {
  id: string;
  type: string;
  title: string;
  body: string;
  isRead: boolean;
  createdAt: string;
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
}
