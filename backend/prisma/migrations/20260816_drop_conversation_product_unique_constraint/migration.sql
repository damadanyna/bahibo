-- Conversations are per buyer/seller pair, not per product: a buyer
-- discussing several products with the same seller must land in one
-- conversation, not a new one per product. `directKey` (symmetric, set on
-- every conversation going forward) is now the sole identity for a pair;
-- this composite index enforced the old per-product uniqueness and must go.
DROP INDEX "ChatConversation_buyerUserId_sellerUserId_productId_key";
