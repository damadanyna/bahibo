--
-- PostgreSQL database dump
--

\restrict 6w19AYU9GKE2sYW9NARYlbuDzYnxQeMnPOjLUAUBOxQhySMFyxNgyOGIYd7y1gT

-- Dumped from database version 17.9
-- Dumped by pg_dump version 17.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ChatConversationKind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."ChatConversationKind" AS ENUM (
    'DIRECT',
    'PRODUCT'
);


ALTER TYPE public."ChatConversationKind" OWNER TO postgres;

--
-- Name: ChatMessageKind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."ChatMessageKind" AS ENUM (
    'TEXT',
    'IMAGE',
    'DOCUMENT',
    'PRODUCT'
);


ALTER TYPE public."ChatMessageKind" OWNER TO postgres;

--
-- Name: OrderStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."OrderStatus" AS ENUM (
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED'
);


ALTER TYPE public."OrderStatus" OWNER TO postgres;

--
-- Name: ShipmentStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."ShipmentStatus" AS ENUM (
    'PENDING',
    'READY',
    'IN_TRANSIT',
    'DELIVERED',
    'FAILED'
);


ALTER TYPE public."ShipmentStatus" OWNER TO postgres;

--
-- Name: ShopRequestStatus; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."ShopRequestStatus" AS ENUM (
    'NONE',
    'PENDING',
    'APPROVED',
    'REJECTED'
);


ALTER TYPE public."ShopRequestStatus" OWNER TO postgres;

--
-- Name: UserRole; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public."UserRole" AS ENUM (
    'CUSTOMER',
    'SELLER',
    'ADMIN'
);


ALTER TYPE public."UserRole" OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Cart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Cart" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "userId" text NOT NULL
);


ALTER TABLE public."Cart" OWNER TO postgres;

--
-- Name: CartItem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."CartItem" (
    id text NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "cartId" text NOT NULL,
    "productId" text NOT NULL
);


ALTER TABLE public."CartItem" OWNER TO postgres;

--
-- Name: Category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Category" (
    id text NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    icon text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."Category" OWNER TO postgres;

--
-- Name: ChatConversation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChatConversation" (
    id text NOT NULL,
    "buyerUserId" text NOT NULL,
    "sellerUserId" text NOT NULL,
    "productId" text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "lastMessageAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "directKey" text,
    kind public."ChatConversationKind" DEFAULT 'PRODUCT'::public."ChatConversationKind" NOT NULL
);


ALTER TABLE public."ChatConversation" OWNER TO postgres;

--
-- Name: ChatMessage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChatMessage" (
    id text NOT NULL,
    "conversationId" text NOT NULL,
    "senderUserId" text NOT NULL,
    content text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "readAt" timestamp(3) without time zone,
    "productId" text,
    "productImageUrl" text,
    "productPriceLabel" text,
    "productSubtitle" text,
    "productTitle" text,
    "replyToContent" text,
    "replyToMessageId" text,
    "replyToSenderName" text,
    "replyToSenderUserId" text,
    kind public."ChatMessageKind" DEFAULT 'TEXT'::public."ChatMessageKind" NOT NULL,
    "deletedForSenderAt" timestamp(3) without time zone,
    "editedAt" timestamp(3) without time zone,
    "deletedForBuyerAt" timestamp(3) without time zone,
    "deletedForSellerAt" timestamp(3) without time zone,
    "clientMessageId" text,
    "acceptedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "deliveredAt" timestamp(3) without time zone
);


ALTER TABLE public."ChatMessage" OWNER TO postgres;

--
-- Name: ChatMessageMedia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ChatMessageMedia" (
    id text NOT NULL,
    "messageId" text NOT NULL,
    "mediaType" text NOT NULL,
    "mimeType" text,
    "fileName" text,
    "fileSizeBytes" integer,
    "storageProvider" text NOT NULL,
    "storageKey" text,
    "publicUrl" text NOT NULL,
    "previewUrl" text,
    "thumbnailUrl" text,
    width integer,
    height integer,
    "encryptionScheme" text,
    "encryptionKeyB64" text,
    "encryptionIvB64" text,
    "fileSha256B64" text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "mediaGroupId" text
);


ALTER TABLE public."ChatMessageMedia" OWNER TO postgres;

--
-- Name: NotificationReadState; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."NotificationReadState" (
    id text NOT NULL,
    "notificationId" text NOT NULL,
    "userId" text NOT NULL,
    "readAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."NotificationReadState" OWNER TO postgres;

--
-- Name: Order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Order" (
    id text NOT NULL,
    "orderNumber" text NOT NULL,
    status public."OrderStatus" DEFAULT 'PENDING'::public."OrderStatus" NOT NULL,
    "subtotalAmount" numeric(12,2) NOT NULL,
    "deliveryAmount" numeric(12,2) NOT NULL,
    "totalAmount" numeric(12,2) NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "buyerUserId" text NOT NULL,
    "sellerProfileId" text NOT NULL
);


ALTER TABLE public."Order" OWNER TO postgres;

--
-- Name: OrderItem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."OrderItem" (
    id text NOT NULL,
    quantity integer NOT NULL,
    "unitPriceAmount" numeric(12,2) NOT NULL,
    "totalPriceAmount" numeric(12,2) NOT NULL,
    "orderId" text NOT NULL,
    "productId" text NOT NULL
);


ALTER TABLE public."OrderItem" OWNER TO postgres;

--
-- Name: PhoneOtpChallenge; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."PhoneOtpChallenge" (
    id text NOT NULL,
    "phoneE164" text NOT NULL,
    "countryName" text,
    "countryDialCode" text,
    "codeHash" text NOT NULL,
    "expiresAt" timestamp(3) without time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    "verifiedAt" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."PhoneOtpChallenge" OWNER TO postgres;

--
-- Name: Product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Product" (
    id text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    "imageUrl" text NOT NULL,
    "priceAmount" numeric(12,2) NOT NULL,
    "currencyCode" text DEFAULT 'MGA'::text NOT NULL,
    "isAvailable" boolean DEFAULT true NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "sellerProfileId" text NOT NULL,
    "categoryId" text NOT NULL
);


ALTER TABLE public."Product" OWNER TO postgres;

--
-- Name: ProductComment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProductComment" (
    id text NOT NULL,
    content text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "userId" text NOT NULL,
    "productId" text NOT NULL,
    "parentCommentId" text
);


ALTER TABLE public."ProductComment" OWNER TO postgres;

--
-- Name: ProductCommentMention; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProductCommentMention" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "commentId" text NOT NULL,
    "mentionedUserId" text NOT NULL
);


ALTER TABLE public."ProductCommentMention" OWNER TO postgres;

--
-- Name: ProductImage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProductImage" (
    id text NOT NULL,
    "imageUrl" text NOT NULL,
    "sortOrder" integer DEFAULT 0 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "productId" text NOT NULL
);


ALTER TABLE public."ProductImage" OWNER TO postgres;

--
-- Name: ProductLike; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProductLike" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "userId" text NOT NULL,
    "productId" text NOT NULL
);


ALTER TABLE public."ProductLike" OWNER TO postgres;

--
-- Name: ProductShare; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."ProductShare" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "userId" text NOT NULL,
    "productId" text NOT NULL
);


ALTER TABLE public."ProductShare" OWNER TO postgres;

--
-- Name: RefreshToken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."RefreshToken" (
    id text NOT NULL,
    "tokenHash" text NOT NULL,
    "expiresAt" timestamp(3) without time zone NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "userId" text NOT NULL
);


ALTER TABLE public."RefreshToken" OWNER TO postgres;

--
-- Name: SearchHistory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SearchHistory" (
    id text NOT NULL,
    "userId" text NOT NULL,
    query text NOT NULL,
    "normalizedQuery" text NOT NULL,
    "resultCount" integer DEFAULT 0 NOT NULL,
    "occurrenceCount" integer DEFAULT 1 NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "lastSearchedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."SearchHistory" OWNER TO postgres;

--
-- Name: SellerFollow; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SellerFollow" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "followerUserId" text NOT NULL,
    "sellerProfileId" text NOT NULL
);


ALTER TABLE public."SellerFollow" OWNER TO postgres;

--
-- Name: SellerLiveSession; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SellerLiveSession" (
    id text NOT NULL,
    "sellerProfileId" text NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    "startedAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "endedAt" timestamp(3) without time zone
);


ALTER TABLE public."SellerLiveSession" OWNER TO postgres;

--
-- Name: SellerProfile; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SellerProfile" (
    id text NOT NULL,
    "studioName" text NOT NULL,
    description text,
    city text,
    country text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "userId" text NOT NULL
);


ALTER TABLE public."SellerProfile" OWNER TO postgres;

--
-- Name: SellerProfileView; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."SellerProfileView" (
    id text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "viewerUserId" text,
    "sellerProfileId" text NOT NULL
);


ALTER TABLE public."SellerProfileView" OWNER TO postgres;

--
-- Name: Shipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."Shipment" (
    id text NOT NULL,
    "carrierName" text,
    "trackingNumber" text,
    "shipmentStatus" public."ShipmentStatus" DEFAULT 'PENDING'::public."ShipmentStatus" NOT NULL,
    "shippedAt" timestamp(3) without time zone,
    "deliveredAt" timestamp(3) without time zone,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "orderId" text NOT NULL
);


ALTER TABLE public."Shipment" OWNER TO postgres;

--
-- Name: User; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."User" (
    id text NOT NULL,
    "phoneE164" text NOT NULL,
    "displayName" text NOT NULL,
    "passwordHash" text NOT NULL,
    "avatarUrl" text,
    "preferredLanguage" text,
    role public."UserRole" DEFAULT 'CUSTOMER'::public."UserRole" NOT NULL,
    "isVerified" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "countryDialCode" text,
    "countryName" text,
    "coverImageUrl" text,
    "locationLabel" text,
    "locationLatitude" double precision,
    "locationLongitude" double precision,
    "locationUpdatedAt" timestamp(3) without time zone,
    "shopRequestReviewedAt" timestamp(3) without time zone,
    "shopRequestStatus" public."ShopRequestStatus" DEFAULT 'NONE'::public."ShopRequestStatus" NOT NULL,
    "shopRequestSubmittedAt" timestamp(3) without time zone,
    "displayNameChangedAt" timestamp(3) without time zone,
    "isSellerCertified" boolean DEFAULT false NOT NULL,
    "sellerVerificationRequestStatus" public."ShopRequestStatus" DEFAULT 'NONE'::public."ShopRequestStatus" NOT NULL,
    "sellerVerificationRequestedAt" timestamp(3) without time zone,
    "sellerVerificationReviewedAt" timestamp(3) without time zone,
    "lastSeenAt" timestamp(3) without time zone
);


ALTER TABLE public."User" OWNER TO postgres;

--
-- Name: UserBlock; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UserBlock" (
    id text NOT NULL,
    "blockerUserId" text NOT NULL,
    "blockedUserId" text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."UserBlock" OWNER TO postgres;

--
-- Name: UserDeviceToken; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UserDeviceToken" (
    id text NOT NULL,
    "userId" text NOT NULL,
    token text NOT NULL,
    platform text,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL,
    "lastSeenAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."UserDeviceToken" OWNER TO postgres;

--
-- Name: UserFeedback; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UserFeedback" (
    id text NOT NULL,
    "userId" text NOT NULL,
    message text NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp(3) without time zone NOT NULL
);


ALTER TABLE public."UserFeedback" OWNER TO postgres;

--
-- Name: UserReport; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."UserReport" (
    id text NOT NULL,
    "reporterUserId" text NOT NULL,
    "reportedUserId" text NOT NULL,
    "conversationId" text,
    reason text,
    details text,
    "blockRequested" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp(3) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public."UserReport" OWNER TO postgres;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO postgres;

--
-- Data for Name: Cart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Cart" (id, "createdAt", "updatedAt", "userId") FROM stdin;
391154b5-38b6-4d84-86a2-a66a1c6ff7ef	2026-04-02 16:43:29.855	2026-04-02 16:43:29.855	b59f5d68-ec21-44d1-adf3-33786f0d3a35
20d36680-fb65-4c52-aa14-b745de903283	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	f299317e-35da-484f-a473-4a66c0adc02d
bbde9ad8-a724-4f26-9222-8d06e40b87dc	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	5beec21f-4030-41a6-b602-2c5228646d8d
39e848ad-607a-47a0-9381-27f18e556154	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	4af03bff-0bbc-46fd-8936-061181dbda80
faab0211-1d31-4d73-9299-868399104cc7	2026-04-02 20:28:04.151	2026-04-02 20:28:04.151	fc758d78-e3c2-4ea7-a489-8e2886635f13
f614cbbc-8596-4701-a1e3-00f9bce8abce	2026-04-02 20:47:00.078	2026-04-02 20:47:00.078	b718efee-173e-441b-98f3-364b40c05e73
5099f93b-85a3-4e90-9ea9-d19ec1df7dc0	2026-04-03 00:19:30.407	2026-04-03 00:19:30.407	f261a10b-c29c-4bd3-a413-bf99ee82cdb0
f359679c-c032-4789-8312-f921931314d9	2026-04-19 16:06:11.822	2026-04-19 16:06:11.822	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
b8aa4bd3-a079-45e6-af3b-8d296a02f38f	2026-04-26 09:50:54.166	2026-04-26 09:50:54.166	9b3b238f-3e67-4073-9b6b-afbd3731f195
e549bce6-529a-44e6-98b1-a5e422a47a25	2026-05-06 16:37:05.22	2026-05-06 16:37:05.22	9a6c8f8b-bd18-4b9e-972f-1179e18da727
aef69177-d384-4a3c-b960-aefcc84f1048	2026-05-13 19:23:42.547	2026-05-13 19:23:42.547	user-admin-demo
57df4da3-1be7-4805-9573-b36f5416244c	2026-05-13 19:23:42.565	2026-05-13 19:23:42.565	user-shop-pending-demo
51923027-3a33-45a9-90d0-41a1bf7cf09a	2026-05-13 19:23:42.568	2026-05-13 19:23:42.568	user-seller-verify-demo
e53ecc5d-dc7f-42f3-8db8-7dd5f28257fd	2026-08-04 18:52:03.156	2026-08-04 18:52:03.156	533ed33f-dbe8-419a-8285-77dd01a553e7
\.


--
-- Data for Name: CartItem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."CartItem" (id, quantity, "createdAt", "updatedAt", "cartId", "productId") FROM stdin;
45507893-1154-47c8-9fe1-6aa82a260cb4	1	2026-04-02 16:43:30.334	2026-05-13 19:24:19.064	391154b5-38b6-4d84-86a2-a66a1c6ff7ef	prod-seed-bag
\.


--
-- Data for Name: Category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Category" (id, name, slug, icon, "createdAt", "updatedAt") FROM stdin;
2712b453-15f3-4e50-a095-e5716fccb144	Moto	moto	\N	2026-04-04 05:59:20.009	2026-04-04 05:59:20.009
65e0a618-b863-4562-b1dd-319e3ef7a197	telephone	telephone	\N	2026-04-04 06:09:35.898	2026-04-04 06:09:35.898
2a64e44f-b82c-451a-95b7-2562177e6c6a	femme	femme	\N	2026-04-04 06:31:49.916	2026-04-04 06:31:49.916
710a07fa-b0cc-4994-b744-45584f9c6a50	uggucic	uggucic	\N	2026-04-04 16:36:36.218	2026-04-04 16:36:36.218
55dd2ced-64b4-4b70-8b06-7250b9fa2fe1	Smartphones	smartphones	📱	2026-04-02 16:43:30.159	2026-05-13 19:24:19.023
e28856dc-ae47-4d6f-abfc-d394b19793fa	Beaute	beauty	🌸	2026-04-02 16:43:30.159	2026-05-13 19:24:19.023
f5df6305-1ab6-4f3b-9972-ebebc10053d5	Mode	fashion	👜	2026-04-02 16:43:30.159	2026-05-13 19:24:19.023
95c627c8-23ee-40eb-87b6-79d1d8256f8f	Maison	home	🪑	2026-04-02 16:43:30.159	2026-05-13 19:24:19.023
0ff5279a-a20f-4094-a5e5-9cb3073d707d	vetement	vetement	\N	2026-05-14 18:45:38.964	2026-05-14 18:45:38.964
\.


--
-- Data for Name: ChatConversation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChatConversation" (id, "buyerUserId", "sellerUserId", "productId", "createdAt", "updatedAt", "lastMessageAt", "directKey", kind) FROM stdin;
a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	fc758d78-e3c2-4ea7-a489-8e2886635f13	\N	2026-05-18 10:00:04.076	2026-05-19 16:08:56.25	2026-05-19 16:08:56.249	b718efee-173e-441b-98f3-364b40c05e73:fc758d78-e3c2-4ea7-a489-8e2886635f13	DIRECT
52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	2026-05-19 18:17:09.515	2026-05-27 20:10:24.157	2026-05-27 20:10:24.155	\N	PRODUCT
1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	7cd76f8d-41f4-45c9-b83b-6dc986840016	2026-05-29 21:02:48.344	2026-08-06 00:56:29.757	2026-08-06 00:56:29.756	\N	PRODUCT
\.


--
-- Data for Name: ChatMessage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChatMessage" (id, "conversationId", "senderUserId", content, "createdAt", "readAt", "productId", "productImageUrl", "productPriceLabel", "productSubtitle", "productTitle", "replyToContent", "replyToMessageId", "replyToSenderName", "replyToSenderUserId", kind, "deletedForSenderAt", "editedAt", "deletedForBuyerAt", "deletedForSellerAt", "clientMessageId", "acceptedAt", "deliveredAt") FROM stdin;
58c5e2cb-3982-42fb-9b35-0aca5934b0e4	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Salut	2026-05-18 10:00:04.088	2026-05-18 10:00:08.01	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
b29c86ce-930a-4b26-a4c9-aad20c6d8edf	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Aiza ilay sary	2026-05-18 10:00:17.115	2026-05-18 10:00:17.266	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
49eb008e-36ff-4751-815e-f170680413f8	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Mba alefaso ato	2026-05-18 10:00:37.623	2026-05-18 10:00:38.046	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
17d3d3c0-cafa-4b0c-8f3c-7f8b44200fa5	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	salut andraso fa alefako ary	2026-05-18 10:00:53.228	2026-05-18 10:00:53.748	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
098454e8-7929-4ea2-987c-ee467da67e40	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	ireo	2026-05-18 10:01:21.838	2026-05-18 10:01:22.349	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
548d652b-8d96-4e77-8d71-28cd3aa98cb1	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:22.5	2026-05-18 10:01:22.726	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
0760e68b-8df2-4678-bc23-465cec582acb	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:22.576	2026-05-18 10:01:22.726	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
d6435ae4-ec71-455f-8e37-9557ac9950c5	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:22.656	2026-05-18 10:01:22.726	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
35e49ffb-5013-4422-84cb-05d5f30b22dc	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:23.057	2026-05-18 10:01:23.072	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
2c0d1969-3623-4ea3-8a21-0a7553d96d83	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:23.209	2026-05-18 10:01:23.449	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
a78a74c4-b2c0-450c-8a87-8c0fdf967f48	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:23.977	2026-05-18 10:01:24.326	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
53436408-ee23-4a05-bc78-95a7c50b323c	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:24.466	2026-05-18 10:01:25.162	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
48ebf7b1-470d-426d-b229-8a93798bf021	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Photo envoyee	2026-05-18 10:01:24.576	2026-05-18 10:01:25.162	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
c4801706-17f5-4098-8e77-22a697f7d993	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Whoaa tsara be	2026-05-18 10:01:37.861	2026-05-18 10:01:38.083	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
0ca2a43a-c82f-4721-ac18-c55a558d0014	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	vola omena raha misy	2026-05-18 10:01:49.283	2026-05-18 10:01:49.86	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
fb0c7464-0c8d-44b0-a28c-0c78766098ee	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	alefaso am ito num ito 0349459128	2026-05-18 10:02:05.477	2026-05-18 10:02:05.989	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
7f1c8b55-a93d-4c97-badf-c4ea53bbddb6	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	vola omena raha misy	2026-05-18 14:58:26.986	2026-05-18 15:02:18.436	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
27ef8bc0-769c-4697-932c-2136b2287cd1	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Photo envoyee	2026-05-18 15:00:06.04	2026-05-18 15:02:18.436	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
8d05849c-a2c1-4e54-844f-071ed1302838	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Photo envoyee	2026-05-18 15:00:06.316	2026-05-18 15:02:18.436	\N	\N	\N	\N	\N	\N	\N	\N	\N	IMAGE	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
53c75232-7122-4f0d-9d13-dd65a99eafe6	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	ihohih	2026-05-27 19:59:02.191	2026-05-27 19:59:02.537	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
bc8ff679-1997-44c8-87f4-b20467bfabf8	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	kuuiuihiuh	2026-05-27 19:59:13.694	2026-05-27 19:59:14.262	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
ebbaa054-0c6b-4a9b-b5ec-9d17b42dcdbf	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Document envoye	2026-05-18 15:00:29.257	2026-05-18 15:02:18.436	\N	\N	\N	\N	\N	\N	\N	\N	\N	DOCUMENT	\N	\N	\N	2026-05-19 15:06:47.377	\N	2026-06-01 22:56:44.753	\N
85502a28-f003-416d-bca8-669432b9eac5	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Document envoye	2026-05-18 15:01:07.203	2026-05-18 15:02:18.436	\N	\N	\N	\N	\N	\N	\N	\N	\N	DOCUMENT	\N	\N	\N	2026-05-19 15:06:47.827	\N	2026-06-01 22:56:44.753	\N
8f9d14ce-8538-4efc-903e-6870e0465b20	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Ma localisation: 3G5H+829\nhttps://maps.google.com/?q=-18.9416418,47.5294558	2026-05-19 05:33:21.869	2026-05-19 15:06:39.435	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	2026-05-19 15:06:48.246	\N	2026-06-01 22:56:44.753	\N
87471317-25b0-468d-b229-bc2f2eabc440	a4aed824-447d-4283-91dc-dce532798fd5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Message supprime	2026-05-19 15:07:06.857	2026-05-19 15:07:41.297	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
a37f1397-d0de-4187-91f2-9d8c72ba0ffc	a4aed824-447d-4283-91dc-dce532798fd5	b718efee-173e-441b-98f3-364b40c05e73	Je te partage ce produit.\nChaise design minimaliste\n145 000	2026-05-19 16:08:56.243	2026-05-19 16:09:01.385	prod-seed-chair	https://images.unsplash.com/photo-1519947486511-46149fa0a254?w=800	145 000	Maison	Chaise design minimaliste	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
514418b8-85c9-44b2-9ae4-103a90241fec	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdijfiosdsdfsdfsdfsdfjsdfj'jezfez	2026-05-27 19:57:51.362	2026-05-27 19:57:51.748	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
cdab8ec8-fa1e-45f9-8225-c7581f1d5e00	52427c4f-c13b-4dd0-8825-78008bd41a18	b718efee-173e-441b-98f3-364b40c05e73	jsjz	2026-05-27 19:58:52.987	2026-05-27 19:58:53.173	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
3e9c1518-d901-47ff-8cb7-d52e7567d647	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfjosidjfoidsjfoisdf	2026-05-27 20:05:26.345	2026-05-27 20:05:32.571	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
c2d3262b-d238-4038-9dbb-319d81e6b68b	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	dfgofdjgoijdfg	2026-05-27 20:05:39.418	2026-05-27 20:05:40.25	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
a4172089-f563-4529-bad8-248db10936ad	52427c4f-c13b-4dd0-8825-78008bd41a18	b718efee-173e-441b-98f3-364b40c05e73	yui	2026-05-27 20:05:43.873	2026-05-27 20:05:44.384	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
1531799f-5069-40b5-8f76-b1b462f69297	52427c4f-c13b-4dd0-8825-78008bd41a18	b718efee-173e-441b-98f3-364b40c05e73	zzhzlehez	2026-05-27 20:05:46.109	2026-05-27 20:05:46.629	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
a8dbeae6-07cd-471f-a923-66bbaa6773a6	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	sndfoisjofijsdoijfsoidfsd	2026-05-27 20:05:58.903	2026-05-27 20:05:59.432	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
e834563c-6161-464d-b4bc-68771429879e	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	fdgdfgfdgdfg	2026-05-27 20:06:07.944	2026-05-27 20:06:08.367	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	\N
4826b9dd-2b68-4ef3-9ca7-cf6164599227	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	squidhuqsidsqd	2026-06-01 21:27:58.593	2026-06-01 21:28:03.921	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780349276977849	2026-06-01 21:27:58.593	2026-06-01 21:27:59.288
86263975-9c67-4277-820f-262afe115944	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdiofjoisdjofjsdf	2026-05-27 20:09:49.092	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:56:45.474
c7d25825-454f-4fa0-bd1b-9ebdc5847878	52427c4f-c13b-4dd0-8825-78008bd41a18	fc758d78-e3c2-4ea7-a489-8e2886635f13	rest	2026-05-27 20:10:24.153	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:56:45.476
c95a90f1-bbe3-4f28-8a16-19daf590a771	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	dsfsdf	2026-06-01 21:25:37.825	2026-06-01 21:25:37.887	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780349136301012	2026-06-01 21:25:37.825	2026-06-01 21:25:38.477
06deb8f7-e8fa-4ed1-ba9b-a36c3bf91e8a	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	Bonjour	2026-06-01 16:41:32.706	2026-06-01 20:57:43.064	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:43.064
df380d4e-d800-4a98-b447-189602f1a247	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	adobe	2026-06-01 20:37:47.435	2026-06-01 20:57:43.064	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:43.064
0374f561-7aa1-49e6-bf2e-4851e7c56d06	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	jskz	2026-06-01 20:37:58.015	2026-06-01 20:57:43.064	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:43.064
93ccda76-ca55-44c4-9f5a-12baaa5ef9c2	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-05-29 21:02:50.352	2026-06-01 20:57:45.554	7cd76f8d-41f4-45c9-b83b-6dc986840016	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784342/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784338965?_a=BAMAOGfk0	12000 MGA	vetement • Disponible	teszpfbe	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:45.554
d37c7b33-1915-4d42-8ee2-4db2591cbc66	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-05-29 21:02:50.352	2026-06-01 20:57:45.554	7cd76f8d-41f4-45c9-b83b-6dc986840016	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784342/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784338965?_a=BAMAOGfk0	12000 MGA	vetement • Disponible	teszpfbe	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:45.554
0cc8689c-1667-40ea-b163-38c2f5b0a60a	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	iuhiuhiu	2026-06-01 20:23:07.38	2026-06-01 20:57:45.554	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	\N	2026-06-01 22:56:44.753	2026-06-01 20:57:45.554
b7368ef5-554d-432c-97e3-539022ff21ce	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	hrzkz	2026-06-01 20:57:50.185	2026-06-01 20:57:50.321	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347469398027	2026-06-01 20:57:50.185	2026-06-01 20:57:51.59
86d02f53-82ce-4c7c-ba3c-6ee00a6a03dc	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	test	2026-06-01 20:58:01.291	2026-06-01 20:58:01.528	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347479516841	2026-06-01 20:58:01.291	2026-06-01 20:58:02.156
0f7c45df-a0cf-4914-a8fb-9eea9f4c89f9	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	testmds	2026-06-01 20:58:09.758	2026-06-01 20:58:09.953	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347488118811	2026-06-01 20:58:09.758	2026-06-01 20:58:10.403
aa85a90b-0fd6-4ffc-8dbd-b9cf4166fcd2	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	test	2026-06-01 20:58:48.797	2026-06-01 20:58:58.485	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347527304174	2026-06-01 20:58:48.797	2026-06-01 20:58:58.485
af5f2f9c-7593-4224-afab-288b85cbfdda	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	xgyi	2026-06-01 21:02:53.408	2026-06-01 21:02:53.427	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347772479337	2026-06-01 21:02:53.408	2026-06-01 21:02:54.121
e8aa59c1-fd6c-4602-a2da-72c93593e6eb	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdtez	2026-06-01 20:59:41.349	2026-06-01 21:05:05.949	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347579844473	2026-06-01 20:59:41.349	2026-06-01 21:05:05.949
e8ba3e6f-2741-4fcd-bc20-deff75d29410	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfojssdsdfqffqsdf	2026-06-01 21:03:06.585	2026-06-01 21:05:05.949	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347785003886	2026-06-01 21:03:06.585	2026-06-01 21:05:05.949
cbda2c9d-d110-48c0-bc4c-8e7701b7c636	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	isodjfsdf	2026-06-01 21:03:35.075	2026-06-01 21:05:05.949	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347813653459	2026-06-01 21:03:35.075	2026-06-01 21:05:05.949
f97c7fb0-1276-4d62-9892-fcd995886e51	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	oijoi	2026-06-01 21:03:45.09	2026-06-01 21:05:05.949	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347823497808	2026-06-01 21:03:45.09	2026-06-01 21:05:05.949
35379513-007e-4b00-b088-affab91fb83a	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdifjosoidjfsdfqhf sq fpqof qf	2026-06-01 21:05:21.505	2026-06-01 21:05:21.767	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347919798832	2026-06-01 21:05:21.505	2026-06-01 21:05:22.157
b7ec6aa8-ea0c-40a6-8b2c-fd71a3cbd6f1	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfosdjf qo jps qdfj pqjfosqjdfsdf	2026-06-01 21:05:28.534	2026-06-01 21:05:28.61	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347926702724	2026-06-01 21:05:28.534	2026-06-01 21:05:29.304
7dd12ee7-45ca-4ca2-965d-d424130c6dac	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sd_fs psq pf psqufpsqu f_usdf_uqs_u fpuq u _up upup_u psudsdfsf	2026-06-01 21:05:40.038	2026-06-01 21:05:40.22	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780347938117975	2026-06-01 21:05:40.038	2026-06-01 21:05:40.81
4c718603-4f95-481e-82ad-8cdce3b000b4	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	🥰	2026-06-01 21:07:29.165	2026-06-01 21:07:39.056	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348047770155	2026-06-01 21:07:29.165	2026-06-01 21:07:39.056
c4239d10-ccd6-4089-a533-87417908d9a4	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	difjsodijf	2026-06-01 21:07:47.224	2026-06-01 21:07:47.368	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348065695882	2026-06-01 21:07:47.224	2026-06-01 21:07:47.891
78058a30-9501-49b6-b2ec-72512ccfbbd1	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	iodjfsodjf	2026-06-01 21:07:56.756	2026-06-01 21:09:16.34	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348074961155	2026-06-01 21:07:56.756	2026-06-01 21:09:16.34
4d65b693-e723-4da3-b40c-9d8257831a2f	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	d,fdoijsidf	2026-06-01 21:10:25.755	2026-06-01 21:10:31.486	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348224293160	2026-06-01 21:10:25.755	2026-06-01 21:10:31.486
a36e2d81-e94f-4d65-815b-56780fcf7ad5	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	reojtoperoekepz'*	2026-06-01 21:10:41.386	2026-06-01 21:10:51.6	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348239713986	2026-06-01 21:10:41.386	2026-06-01 21:10:51.6
7d62c9b1-239b-4b2b-a9c0-fc8558c4aef2	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfopsdfpojsdsdf	2026-06-01 21:10:47.409	2026-06-01 21:10:51.6	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348245688618	2026-06-01 21:10:47.409	2026-06-01 21:10:51.6
e4bceaa7-4429-461f-8566-94592c9fabcd	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdnfdsoifjsdf	2026-06-01 21:13:21.02	2026-06-01 21:13:28.181	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348399088385	2026-06-01 21:13:21.02	2026-06-01 21:13:28.181
8bc9223c-2a28-471d-b171-89a78d25232e	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	bonne nuit	2026-06-01 21:17:53.092	2026-06-01 21:17:57.614	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348671229784	2026-06-01 21:17:53.092	2026-06-01 21:17:53.865
36ebbe9b-3fa5-4e10-8102-96a7afbe876a	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdoisdif	2026-06-01 21:21:53.359	2026-06-01 21:21:56.903	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348911387289	2026-06-01 21:21:53.359	2026-06-01 21:21:54.022
53fcc5fd-a20e-4c44-98a2-1e436f8ed93f	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	dsfsdfjsdf	2026-06-01 21:22:14.886	2026-06-01 21:22:18.673	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780348933092761	2026-06-01 21:22:14.886	2026-06-01 21:22:15.481
d177e156-d0bc-4498-a360-b22df61f0c52	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	iosdiofjsdf	2026-06-01 21:23:41.064	2026-06-01 21:23:41.15	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780349019317003	2026-06-01 21:23:41.064	2026-06-01 21:23:41.776
08bb200f-8fed-4587-be61-1ab56b77c9b2	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	isdjfosdfsdf	2026-06-01 21:25:28.262	2026-06-01 21:25:28.487	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780349126299359	2026-06-01 21:25:28.262	2026-06-01 21:25:28.915
26719a4a-3f2f-47b9-98e7-1a64e95ce8b2	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdhufihsidf	2026-06-01 21:28:24.811	2026-06-01 21:28:24.978	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1780349302983165	2026-06-01 21:28:24.811	2026-06-01 21:28:25.528
6126f8b6-8f9b-4233-9b84-a25402765b26	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	Bonjour	2026-06-09 19:12:07.132	2026-06-09 19:12:33.741	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781032298608407	2026-06-09 19:12:07.132	2026-06-09 19:12:33.741
208b57e1-6544-415d-a548-fe1b4f6edabe	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	dsosdjfpdsf	2026-06-09 19:12:23.644	2026-06-09 19:12:33.741	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781032315450264	2026-06-09 19:12:23.644	2026-06-09 19:12:33.741
5750d684-a0ed-4aa9-bb76-fae6030db17e	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	oepe	2026-06-09 19:13:09.276	2026-06-09 19:13:26.821	\N	\N	\N	\N	\N	dsfsdf	c95a90f1-bbe3-4f28-8a16-19daf590a771	DAMA Dany	\N	TEXT	\N	\N	\N	\N	pending-text-1781032388241461	2026-06-09 19:13:09.276	2026-06-09 19:13:26.821
f43eb4b5-4516-4077-bacb-7fd56b91e100	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	eueuie	2026-06-09 19:13:12.81	2026-06-09 19:13:26.821	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781032392052640	2026-06-09 19:13:12.81	2026-06-09 19:13:26.821
36464092-13bb-4f40-8df7-8e868380562b	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	khuhu	2026-06-09 19:13:48.019	2026-06-09 19:13:56.15	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781032399707870	2026-06-09 19:13:48.019	2026-06-09 19:13:48.886
9eeb7f5b-dc71-4c9b-90b1-b3bf3b4cdbc3	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	nuni	2026-06-09 19:13:59.577	2026-06-09 19:14:06.795	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781032411402794	2026-06-09 19:13:59.577	2026-06-09 19:14:06.795
75457d36-d26d-4de9-bee5-c72201a7f106	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	iojsodijfsdf	2026-06-09 19:51:23.236	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781034655065163	2026-06-09 19:51:23.236	2026-06-09 19:51:24.313
927eac8f-bc38-40a9-bd6a-248629b6054d	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	oijoihoi	2026-06-09 19:52:36.489	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781034727654339	2026-06-09 19:52:36.489	2026-06-09 19:53:19.941
90011cb0-21a1-487d-ac9a-625c4430a38e	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdfoijsdfsdf	2026-06-09 19:53:31.191	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781034782002344	2026-06-09 19:53:31.191	2026-06-09 19:53:41.991
ec9724bc-0a76-4122-9ffb-83300b650f7b	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	odsfopdsfdsf	2026-06-09 19:58:57.841	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035109447885	2026-06-09 19:58:57.841	2026-06-09 19:59:00.404
af7021c9-d3c1-4cb6-97d5-bec101548187	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdfjoisjdfosdfsf	2026-06-09 19:59:19.762	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035131563181	2026-06-09 19:59:19.762	2026-06-09 19:59:20.62
2469e49d-b94f-4f85-bb1c-e6fab0b41b3b	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdfjoisdfijsdf	2026-06-09 19:59:36.776	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035148643464	2026-06-09 19:59:36.776	2026-06-09 19:59:37.595
e9ff36f9-6339-4f76-b860-64473f6311bc	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	idjfoisdfdsf	2026-06-09 20:08:28.104	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035679657213	2026-06-09 20:08:28.104	2026-06-09 20:08:29.662
3cadf7df-2cef-44fd-8d49-4b259b163ec8	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	esdfijsdoijfoisjdfdsf	2026-06-09 20:08:36.428	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035688132560	2026-06-09 20:08:36.428	2026-06-09 20:08:37.297
30d88bad-5493-4eb4-86be-53a7b755edd7	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	usqihduiqhsiud	2026-06-09 20:11:00.158	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035831643661	2026-06-09 20:11:00.158	2026-06-09 20:11:01.557
e164fab9-ce3f-45b1-bb6c-439107d2eb78	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdifjosidjfoisdf	2026-06-09 20:11:10.663	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035842226510	2026-06-09 20:11:10.663	2026-06-09 20:11:24.411
3dc557ec-2462-49f1-afc3-27449d4a3201	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sidjfoidsf	2026-06-09 20:11:16.166	2026-06-09 20:11:29.329	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035847829598	2026-06-09 20:11:16.166	2026-06-09 20:11:24.413
2a53724e-3ea5-4531-a143-701a843b5dcf	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	siodjfosjdfosdf	2026-06-09 20:11:37.601	2026-06-09 20:11:51.225	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035869431801	2026-06-09 20:11:37.601	\N
4e203802-3463-488d-a38d-49d5ca7fcbf3	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sjdiofjosdf	2026-06-09 20:11:42.706	2026-06-09 20:11:51.225	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035874383748	2026-06-09 20:11:42.706	\N
ad54a165-17b5-403c-b5d5-49e3ca58a206	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	dsifjoidsjdsf	2026-06-09 20:12:13.265	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035904803156	2026-06-09 20:12:13.265	2026-06-09 20:13:27.547
d4827431-6fa8-4502-977a-64c097782423	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdjfoisdf	2026-06-09 20:12:27.301	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781035918659666	2026-06-09 20:12:27.301	2026-06-09 20:13:27.551
ad59dad4-2d5f-4af1-9ee9-eeefa0421bbf	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	ohsdosdsf	2026-06-10 04:18:53.36	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781065081228033	2026-06-10 04:18:53.36	2026-06-10 04:18:55.296
6cb51de1-76bf-4772-bf7e-fe268cc19219	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdfijsdoijfoisddsf	2026-06-10 04:19:03.675	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781065091563918	2026-06-10 04:19:03.675	2026-06-10 04:19:04.532
9d046cfa-bb53-4c1a-acf7-0959bb6c7532	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	sdfiojdsofjsdiofsdf	2026-06-10 04:19:15.689	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781065103646253	2026-06-10 04:19:15.689	\N
764330b5-7a64-4e6b-9662-0ed95e1aba56	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	TEste TEste TEste	2026-06-10 04:19:49.232	2026-06-10 04:19:57.461	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1781065137213119	2026-06-10 04:19:49.232	\N
8f00f1df-a0d3-451c-86ac-0bf2053e4942	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	b718efee-173e-441b-98f3-364b40c05e73	Bonjour est ce que a marche?	2026-08-06 00:37:04.27	2026-08-06 00:37:12.769	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1785976526009707	2026-08-06 00:37:04.27	2026-08-06 00:37:06.588
083188c2-ffd0-4c20-a73f-b95e18bea731	1a71297d-8c0d-4de9-aab1-df13b5e7ce43	fc758d78-e3c2-4ea7-a489-8e2886635f13	oui oui	2026-08-06 00:56:29.702	2026-08-06 01:04:34.54	\N	\N	\N	\N	\N	\N	\N	\N	\N	TEXT	\N	\N	\N	\N	pending-text-1785977789669451	2026-08-06 00:56:29.702	2026-08-06 00:56:31.722
\.


--
-- Data for Name: ChatMessageMedia; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChatMessageMedia" (id, "messageId", "mediaType", "mimeType", "fileName", "fileSizeBytes", "storageProvider", "storageKey", "publicUrl", "previewUrl", "thumbnailUrl", width, height, "encryptionScheme", "encryptionKeyB64", "encryptionIvB64", "fileSha256B64", "createdAt", "updatedAt", "mediaGroupId") FROM stdin;
1ef50914-91dc-464b-9763-0bfcb9bb3a44	27ef8bc0-769c-4697-932c-2136b2287cd1	image	image/jpeg	scaled_1000011217.jpg	384063	cloudinary	BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402300	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402300.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402300.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402300.jpg	1200	1600	\N	\N	\N	\N	2026-05-18 15:00:06.04	2026-05-18 15:00:06.04	image-1779116402354156
2c5fd3d8-2b8f-4efd-8651-3c8949fd9e7d	8d05849c-a2c1-4e54-844f-071ed1302838	image	image/jpeg	scaled_1000011216.jpg	382896	cloudinary	BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402429	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402429.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402429.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779116404/BANAY/chat-images/b718efee173e441b98f3364b40c05e73-chat-image-1779116402429.jpg	1200	1600	\N	\N	\N	\N	2026-05-18 15:00:06.316	2026-05-18 15:00:06.316	image-1779116402354156
07009a50-d121-44cb-a30c-a0d0898ad104	ebbaa054-0c6b-4a9b-b5ec-9d17b42dcdbf	document	application/pdf	Entre stabilité et liberté.pdf	2340112	cloudinary	BANAY/chat-documents/b718efee173e441b98f3364b40c05e73-chat-document-1779116424802.pdf	https://res.cloudinary.com/dedzvlmsf/raw/upload/v1779116428/BANAY/chat-documents/b718efee173e441b98f3364b40c05e73-chat-document-1779116424802.pdf	\N	\N	\N	\N	\N	\N	\N	\N	2026-05-18 15:00:29.257	2026-05-18 15:00:29.257	\N
f11fccf0-feb8-4ae7-8b55-c7a737df3b40	85502a28-f003-416d-bca8-669432b9eac5	document	application/pdf	Reçu du billet électronique, 11 février pour MS VO_260206_133448.pdf	49624	cloudinary	BANAY/chat-documents/b718efee173e441b98f3364b40c05e73-chat-document-1779116464462.pdf	https://res.cloudinary.com/dedzvlmsf/raw/upload/v1779116466/BANAY/chat-documents/b718efee173e441b98f3364b40c05e73-chat-document-1779116464462.pdf	\N	\N	\N	\N	\N	\N	\N	\N	2026-05-18 15:01:07.203	2026-05-18 15:01:07.203	\N
77a36791-eeb6-4ea9-87ea-bb7553bb549a	548d652b-8d96-4e77-8d71-28cd3aa98cb1	image	image/jpeg	scaled_1000110480.jpg	230835	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478532	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478532.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478532.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478532.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:22.5	2026-05-18 10:01:22.5	image-1779098478441312
9d27c2da-fdc3-4de9-83dc-4f6fd1216ec3	0760e68b-8df2-4678-bc23-465cec582acb	image	image/jpeg	scaled_1000110476.jpg	318423	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478384	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478384.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478384.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478384.jpg	1600	747	\N	\N	\N	\N	2026-05-18 10:01:22.576	2026-05-18 10:01:22.576	image-1779098478441312
2cf432b4-4a06-4101-a595-3214e3e5a78a	d6435ae4-ec71-455f-8e37-9557ac9950c5	image	image/jpeg	scaled_1000110478.jpg	274457	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478791	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478791.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478791.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478791.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:22.656	2026-05-18 10:01:22.656	image-1779098478441312
5e8783e5-f3a4-4d10-be22-586bbe28d906	35e49ffb-5013-4422-84cb-05d5f30b22dc	image	image/jpeg	scaled_1000110482.jpg	259435	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478999	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478999.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478999.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098478999.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:23.057	2026-05-18 10:01:23.057	image-1779098478441312
a7d9ea31-94bc-4446-8ed6-120342103d59	2c0d1969-3623-4ea3-8a21-0a7553d96d83	image	image/jpeg	scaled_1000110472.jpg	255638	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479151	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479151.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479151.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479151.jpg	1600	747	\N	\N	\N	\N	2026-05-18 10:01:23.209	2026-05-18 10:01:23.209	image-1779098478441312
ecf242cf-9323-4366-9cbb-ba7cfae76f19	a78a74c4-b2c0-450c-8a87-8c0fdf967f48	image	image/jpeg	scaled_1000110462.jpg	187109	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479678	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479678.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479678.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098481/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479678.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:23.977	2026-05-18 10:01:23.977	image-1779098478441312
83ce188d-0eab-4ba8-8ab1-2bccea1abf18	53436408-ee23-4a05-bc78-95a7c50b323c	image	image/jpeg	scaled_1000110464.jpg	387346	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479534	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479534.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479534.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479534.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:24.466	2026-05-18 10:01:24.466	image-1779098478441312
7283a307-0c48-4b8e-bf27-57b6fb59d9ad	48ebf7b1-470d-426d-b229-8a93798bf021	image	image/jpeg	scaled_1000110461.jpg	365574	cloudinary	BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479554	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479554.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479554.jpg	https://res.cloudinary.com/dedzvlmsf/image/upload/v1779098482/BANAY/chat-images/fc758d78e3c24ea7a4898e2886635f13-chat-image-1779098479554.jpg	747	1600	\N	\N	\N	\N	2026-05-18 10:01:24.576	2026-05-18 10:01:24.576	image-1779098478441312
\.


--
-- Data for Name: NotificationReadState; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."NotificationReadState" (id, "notificationId", "userId", "readAt") FROM stdin;
815cba3a-32cf-4edc-912e-d8376f281451	notif-profile-view-cddc0066-1179-4a16-aa8a-7edeea79d0bc	b718efee-173e-441b-98f3-364b40c05e73	2026-04-08 02:03:43.393
24584f6f-6619-4095-805b-cc14d72917c1	notif-like-c79d01a5-8872-4e86-b588-9e6c98b53bd2	b718efee-173e-441b-98f3-364b40c05e73	2026-04-08 02:03:51.763
33261fd3-af32-4a46-b9db-9280367ffdbd	notif-like-1d3d6860-131f-4c8e-aa45-737a0f27d81b	b718efee-173e-441b-98f3-364b40c05e73	2026-04-08 02:03:57.983
85a5e240-1be7-4ad0-803c-a478d2fcdd2a	notif-product-update-1d3d6860-131f-4c8e-aa45-737a0f27d81b	fc758d78-e3c2-4ea7-a489-8e2886635f13	2026-04-08 02:11:16.18
6a6aea0b-e07e-445c-bcf3-fb3a7d582a1f	notif-like-3a4a58b8-8f96-42dd-b14f-f0ba045747e4	b718efee-173e-441b-98f3-364b40c05e73	2026-04-13 15:51:00.16
b4fb6cc1-2d5c-4139-b87f-ed9d5ebff3e1	notif-comment-3a4a58b8-8f96-42dd-b14f-f0ba045747e4	b718efee-173e-441b-98f3-364b40c05e73	2026-04-19 16:12:29.713
03a275a2-ecb4-48e4-93a5-845da6c941af	notif-like-30e26f74-1462-4829-bb70-beea516822f3	b718efee-173e-441b-98f3-364b40c05e73	2026-04-19 16:41:57.036
128ba1ea-1f2c-4050-8847-4414a1a29353	notif-like-4bae1fb8-7119-4588-a44c-7c98cd77fb2e	b718efee-173e-441b-98f3-364b40c05e73	2026-04-19 16:41:59.982
11781431-fee8-42c0-b8d9-13eb60bd6d0c	notif-seller-follow-8251534e-e1e7-466d-b917-1c6b51d79c15	b718efee-173e-441b-98f3-364b40c05e73	2026-04-26 09:51:33.468
507e2b06-1eed-4e33-af77-bbd36b587ee6	notif-user-feedback-feedback-admin-demo-1	fc758d78-e3c2-4ea7-a489-8e2886635f13	2026-05-16 07:33:39.172
284c493a-5dcb-45f4-8f2b-06a7350fba53	notif-seller-follow-0c74cbbf-78e8-4974-9bfe-fc704fbdcace	b718efee-173e-441b-98f3-364b40c05e73	2026-05-19 15:34:27.891
90417295-5c6f-43be-8984-edccead6cb53	notif-seller-follow-d692aeed-65bd-4974-b400-6da32d87c227	b718efee-173e-441b-98f3-364b40c05e73	2026-05-19 15:34:29.899
18403eb7-dc4b-4697-b3fa-6d81260f6fae	notif-shop-request-approved-b718efee-173e-441b-98f3-364b40c05e73-1775278702354	b718efee-173e-441b-98f3-364b40c05e73	2026-05-19 15:34:30.905
\.


--
-- Data for Name: Order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Order" (id, "orderNumber", status, "subtotalAmount", "deliveryAmount", "totalAmount", "createdAt", "updatedAt", "buyerUserId", "sellerProfileId") FROM stdin;
e9daebd9-2af7-45cf-ade7-e4dc5fa0d4a9	BHB-SEED-001	DELIVERED	190000.00	15000.00	205000.00	2026-04-02 16:43:30.355	2026-05-13 19:24:19.066	b59f5d68-ec21-44d1-adf3-33786f0d3a35	6a138d49-94b3-4f80-9e9b-cf137bc0a245
\.


--
-- Data for Name: OrderItem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."OrderItem" (id, quantity, "unitPriceAmount", "totalPriceAmount", "orderId", "productId") FROM stdin;
4ec42755-c098-4c3a-a09f-7dd3713f0f23	1	190000.00	190000.00	e9daebd9-2af7-45cf-ade7-e4dc5fa0d4a9	prod-seed-perfume
\.


--
-- Data for Name: PhoneOtpChallenge; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."PhoneOtpChallenge" (id, "phoneE164", "countryName", "countryDialCode", "codeHash", "expiresAt", attempts, "verifiedAt", "createdAt", "updatedAt") FROM stdin;
34f5d719-9afb-4717-be58-c536d932a5b1	+261349459128	Madagascar	+261	$2a$10$fRcZtl1XAP9A42X5BIQIH.zGD0EeZ7.lg21DRMI9De70wSEzQuuYa	2026-04-02 18:24:48.27	0	2026-04-02 18:20:10.484	2026-04-02 18:19:48.271	2026-04-02 18:20:10.485
8d469ff0-3c47-4704-a925-d4f298533a6d	+261349459128	Madagascar	+261	$2a$10$Uy3MpEKbQWtOLYhtMgeSpu9Seu0ROjLmbdS2gHnoxOlrgmjt0ER22	2026-04-02 18:30:15.204	0	2026-04-02 18:25:40.162	2026-04-02 18:25:15.207	2026-04-02 18:25:40.165
af8f1103-7279-4ae9-b377-daa65ac7a618	+261349459128	Madagascar	+261	$2a$10$dZ.ltFowjYUM5tNoW/74NuzhQmz64DnDJ1gESy7uCqOzhdRuUHUjO	2026-04-02 18:31:11.037	0	2026-04-02 18:26:24.348	2026-04-02 18:26:11.04	2026-04-02 18:26:24.358
1ca6fc01-734a-4dc8-a905-37ce695346a6	+261349459128	Madagascar	+261	$2a$10$cTEcCe6v/.GKZ/wyndf0V.FctNdOqfPKIh5NhkdCBEYRItcfveAzW	2026-04-02 19:54:01.768	0	2026-04-02 19:51:25.009	2026-04-02 19:49:01.773	2026-04-02 19:51:25.02
84f2b11e-97e9-46e8-be6d-2bfce0b54267	+261349459128	Madagascar	+261	$2a$10$NnB2zBylHUDUebRNYUqYhuWp1Pv5pBGSNHR2YTjQC6V42XiWEuHea	2026-04-02 19:57:22.1	0	2026-04-02 19:52:27.989	2026-04-02 19:52:22.112	2026-04-02 19:52:27.992
0f66b387-27d2-419d-be4c-e6836580dc24	+261349459128	Madagascar	+261	$2a$10$JeNrriQJ6wUXnkggwdqnI.XdEa6e9C6FjxLa69f0T5sGYbnC2ON0O	2026-04-02 20:09:00.174	0	2026-04-02 20:04:10.717	2026-04-02 20:04:00.18	2026-04-02 20:04:10.723
73d2c666-1967-4c1b-a7ad-1947c9a5db1f	+261349459128	Madagascar	+261	$2a$10$SDAgxyymCiemQvxEl7nvhepY3FO.YgfSXA6GnMBBHEOzbIO4Fkz.u	2026-04-02 20:18:11.264	0	2026-04-02 20:13:22.756	2026-04-02 20:13:11.278	2026-04-02 20:13:22.769
105dbd8a-c173-4f66-8df0-088efa01caf7	+261349459128	Madagascar	+261	$2a$10$/jgmH7ftCvejnqGIhwQqbuQQK0cZMV7sRMP.Sf9eKd6GCOrTzgVxy	2026-04-02 20:32:22.318	0	2026-04-02 20:27:29.721	2026-04-02 20:27:22.319	2026-04-02 20:27:29.722
8492c4f4-1b63-41ee-9568-8f9aa9421655	+261342307565	Madagascar	+261	$2a$10$qkckn6SqIBRpkbiloImlDu6pbTc4GRdpwfvx0Y4Z4ihjamUte0cUG	2026-04-02 20:51:29.412	0	2026-04-02 20:46:47.89	2026-04-02 20:46:29.415	2026-04-02 20:46:47.892
260b049b-809a-46b1-bb7f-22ff6c5bf27b	+261342307565	Madagascar	+261	$2a$10$CheX/XactiOZZu.f/7BNPeT1p6Ddzk4rzDyJho9QJpAb41v/wSq4a	2026-04-02 23:20:09.303	0	2026-04-02 23:15:24.668	2026-04-02 23:15:09.305	2026-04-02 23:15:24.669
dcf2b9a3-1918-48f2-8003-5f9f37b0e138	+261349459128	Madagascar	+261	$2a$10$EosSLKX/dj8QB9.zG2UkSe47D0R4/YHjyG8HNV.tleMyMUQyPdfl6	2026-04-03 00:01:52.446	0	2026-04-02 23:57:04.009	2026-04-02 23:56:52.448	2026-04-02 23:57:04.01
64dafd59-0f39-4557-b3c3-2a3f1f895a3e	+261346484348	Madagascar	+261	$2a$10$0nOSsbJ/fzNw036g2oXSwee2C90gYpMhz6MaaQyXUNfzOxNEnASwW	2026-04-03 00:24:05.444	0	2026-04-03 00:19:12.765	2026-04-03 00:19:05.447	2026-04-03 00:19:12.767
0573ad1b-e26d-4ec8-b788-b9043be38083	+261349459128	Madagascar	+261	$2a$10$I13VvvFy/LxLKE5aMvf1uu0qWGoUzNyCazM0GoEyAnP25dHbru5d2	2026-04-03 04:41:05.732	0	2026-04-03 04:36:12.871	2026-04-03 04:36:05.736	2026-04-03 04:36:12.872
30b54f40-f65b-4244-93a2-c44e8049ef81	+261349459128	Madagascar	+261	$2a$10$VZq3fJbfiYbUE2qlwxWstOYpDfyUJljNJl/CnWiKEkinDb3DXR9CK	2026-04-04 03:23:09.225	0	2026-04-04 03:18:39.473	2026-04-04 03:18:09.228	2026-04-04 03:18:39.474
dc04af76-111f-4708-8670-ee8fccf6e196	+261342307565	Madagascar	+261	$2a$10$A3..UYacw91zEu5Z9Nqpse1ueEtPnNd0L8LkqS.4H6drbMidbTsxC	2026-04-03 04:41:50.256	1	2026-04-03 04:37:14.974	2026-04-03 04:36:50.258	2026-04-03 04:37:14.975
604e1109-871c-4702-af93-379aeddde32a	+261342307565	Madagascar	+261	$2a$10$vT21Uua46Z8n4.co7S.9UeFxMD5y4UIP4WI1Vg8GihbvQ76U3vlWu	2026-04-03 10:12:22.491	0	2026-04-03 10:07:31.151	2026-04-03 10:07:22.492	2026-04-03 10:07:31.153
32da730c-74dd-4285-8226-4d21fa32294b	+261342307565	Madagascar	+261	$2a$10$iel5SovVOlXAUbX/uagHY..DZRy3B9uPIOd5OODU8FkqeL1IQYf4m	2026-04-03 10:38:37.518	0	2026-04-03 10:34:24.371	2026-04-03 10:33:37.519	2026-04-03 10:34:24.372
ef03989e-73c3-42f0-a94e-e12d9585ae00	+261342307565	Madagascar	+261	$2a$10$1uXFVD4f30BdBTJMrbYc0.tGVP9Zc18GKYAIT3SZJC3KA79xDTWki	2026-04-03 16:46:39.268	0	2026-04-03 16:41:49.847	2026-04-03 16:41:39.271	2026-04-03 16:41:49.848
02af005b-9677-4dbd-bb96-829e381cb616	+261342307565	Madagascar	+261	$2a$10$rm4HNSM/T0zSmN6HCdyOKu44hwt7eUj9XTUhaqNs4HQD1S.6svbYq	2026-04-04 15:11:41.006	0	2026-04-04 15:06:41.23	2026-04-04 15:06:41.009	2026-04-04 15:06:41.232
df9090a8-5dd7-4e69-872d-e99b1a096b36	+261349459128	Madagascar	+261	$2a$10$B.6qmPj7QCHh6Qda1zLxteh8FZDEandGaHA/nUOfpitoqEEZ1ghiC	2026-04-04 03:32:34.682	0	2026-04-04 03:27:44.965	2026-04-04 03:27:34.684	2026-04-04 03:27:44.966
d6dd4eba-3b15-45d5-a347-550d26722b93	+261349459128	Madagascar	+261	$2a$10$IGNcO5LQOvREq85jT5nhaeq9paynSq6ri2QETS5JOAz5J6UZN8CgO	2026-04-04 03:59:39.937	0	2026-04-04 03:54:55.622	2026-04-04 03:54:39.939	2026-04-04 03:54:55.625
4896af2d-2a60-4209-a1f1-414d506e9b0d	+261349459128	Madagascar	+261	$2a$10$f8./3YlROM1IgiZe/kAaoO488GoesuC1ntY3PzFKci3XQMVkgoami	2026-04-04 04:16:57.531	0	2026-04-04 04:12:06.202	2026-04-04 04:11:57.536	2026-04-04 04:12:06.204
ed2e9dbb-3aec-489f-8337-26bbcf7f3f2b	+261342307565	Madagascar	+261	$2a$10$P2Ghsa4aofTZ5UpUUKB0gemAvGt1c2BlVpTKQ39ViXn96hFiz87Jy	2026-04-04 04:17:46.469	0	2026-04-04 04:13:01.855	2026-04-04 04:12:46.47	2026-04-04 04:13:01.857
0710d262-8eea-4f79-9a56-c2264d49496b	+261349459128	Madagascar	+261	$2a$10$2nN2y9M8P80ilMFTK8W/Cu8ihR5sIP4xU0z43CJ9L3vqQ1ZwMOCBe	2026-04-04 04:43:30.682	0	2026-04-04 04:38:39.165	2026-04-04 04:38:30.684	2026-04-04 04:38:39.167
b22080f4-9b97-4760-94dd-5e1b5da73c46	+261349459128	Madagascar	+261	$2a$10$FUNMn9c.Z7UR20jlxnossuj0y2./TUni1AeGWTvercWyqYKnUgsWe	2026-04-04 05:02:18.078	0	2026-04-04 04:57:33.061	2026-04-04 04:57:18.079	2026-04-04 04:57:33.062
c14f2fc5-4918-490d-b132-5870602e632f	+261342307565	Madagascar	+261	$2a$10$ufzF5XJGN2.iomiTHabYguO3V8zFp/hOkyQM4FoivG85U1PEL2uRC	2026-04-04 14:53:20.455	0	2026-04-04 14:48:27.677	2026-04-04 14:48:20.458	2026-04-04 14:48:27.678
cbd9886e-3fa9-4a71-bfed-ed5231e66416	+261342307565	Madagascar	+261	$2a$10$9sOijg4a1s9mFTo0oBpI3eBn7QaeWk6O4jDeKyBoVi4RCk3NCZswO	2026-04-04 15:09:40.045	0	2026-04-04 15:04:40.133	2026-04-04 15:04:40.046	2026-04-04 15:04:40.134
987d8394-b06e-438d-8be4-a830c72e4c1e	+261342307565	Madagascar	+261	$2a$10$aztDz9EEwVQVQw54xd6YdeThrmgOtnEHAFKhfbVvATpSKwvgCHYJi	2026-04-04 15:14:26.824	0	2026-04-04 15:09:28.191	2026-04-04 15:09:26.825	2026-04-04 15:09:28.193
832baddd-a4b0-4037-99ad-cecf8d450fee	+261342307565	Madagascar	+261	$2a$10$Z6CYsaD8.nP9d7SBcgqlTO5z4pUjHEvVNrkCf0hI.CZuxupRYO.Au	2026-04-04 15:24:17.172	0	2026-04-04 15:19:18.482	2026-04-04 15:19:17.175	2026-04-04 15:19:18.484
52aa6878-258e-4c1a-8e90-cd4fe5cc7796	+261342307565	Madagascar	+261	$2a$10$7cNFxq0HE1xxxCZt.GZDEu.GjAas3JgSicpDYy8qX.uLE4YdWj43q	2026-04-04 15:25:21.647	0	2026-04-04 15:20:22.932	2026-04-04 15:20:21.65	2026-04-04 15:20:22.934
019fc693-c69b-4393-b6d1-a330e9c3c4a5	+261342307565	Madagascar	+261	$2a$10$JlAAi86RUO4T6E.SVSMAl.zC2yZ5dHy0iTOWFnN1sO60ZlT.ylG.m	2026-04-04 15:30:03.703	0	2026-04-04 15:25:05.136	2026-04-04 15:25:03.704	2026-04-04 15:25:05.137
94bfdd14-5ab4-48e2-a4bc-76382f552168	+261342307565	Madagascar	+261	$2a$10$KA3aCzErSdHKjVlcZ2Num.0w4EHUVljFqmkRP3Q5V6zIPqRa51oWq	2026-04-04 15:33:24.597	0	2026-04-04 15:28:26.11	2026-04-04 15:28:24.598	2026-04-04 15:28:26.112
e411fbc8-1bfa-46f4-aed0-abd9f77b9e4b	+261342307565	Madagascar	+261	$2a$10$6yG/BhOvj21qAyfb9gpV6eafgHVvln5bHMMNnlUn0.0p87UdDTeuy	2026-04-04 15:52:09.794	0	2026-04-04 15:47:10.477	2026-04-04 15:47:09.795	2026-04-04 15:47:10.478
d86240fd-b96f-45a6-8fd6-cabfda42fc03	+261342307565	Madagascar	+261	$2a$10$sECzjfGuQvqWEquE8aLtCuVHQjoXMfoWF1.BS6Cxchxs3vB8zHSru	2026-04-04 15:54:52.462	0	2026-04-04 15:49:53.218	2026-04-04 15:49:52.463	2026-04-04 15:49:53.22
7aec9474-0289-4d3f-a19a-3048f2e0af5a	+261342307565	Madagascar	+261	$2a$10$hofULKOe1J2BtvetaCrJTOaHhxzP98PkRLUhAEI5XMgg1Ihx/YzpG	2026-04-04 16:33:40.05	0	2026-04-04 16:28:40.501	2026-04-04 16:28:40.053	2026-04-04 16:28:40.503
110e4146-8bd3-4a58-a76b-a1f0da51d7b9	+261342307565	Madagascar	+261	$2a$10$fBe5.iWFMchWrsKlkx7L8O7gWOyVm7TusxJZRZQnMFsHrYABmq7KK	2026-04-04 16:36:24.727	0	2026-04-04 16:31:25.337	2026-04-04 16:31:24.739	2026-04-04 16:31:25.348
fd5dc605-1485-42db-90f5-395a8116b655	+261342307565	Madagascar	+261	$2a$10$9dSbj9gpSQt4AExcIeCXnut.LWLP/rI7pdLfcKgyGffuMCsKrJQtu	2026-04-04 16:39:04.231	0	2026-04-04 16:34:04.667	2026-04-04 16:34:04.233	2026-04-04 16:34:04.669
559c91de-91a6-4cbd-9b59-62cf54e5d4af	+261342307565	Madagascar	+261	$2a$10$KOWoowtJFqXFg5tc4xDPzef/3yhfNzwe4bW02GlLAqzuKxUJJ97IW	2026-04-04 16:40:28.115	0	2026-04-04 16:35:28.475	2026-04-04 16:35:28.117	2026-04-04 16:35:28.477
5dc22d7a-6c7f-4aba-af5a-17cc8b7a672b	+261349459128	Madagascar	+261	$2a$10$jfSaPiWkp.xQrKWZJZ2wK.xg.xXiyriIpL0.cGzrOtidrVm6Kta82	2026-04-05 12:04:34.442	0	2026-04-05 11:59:34.867	2026-04-05 11:59:34.445	2026-04-05 11:59:34.868
079602e4-724f-4abe-a374-358f46cecb80	+261342307565	Madagascar	+261	$2a$10$Q4JH.VvQpB9/gH4XllSaD.ze9LHC/rV20N2MB5lCZknWr5WigL5Xy	2026-04-05 15:56:29.882	0	2026-04-05 15:51:30.375	2026-04-05 15:51:29.886	2026-04-05 15:51:30.376
8b47d154-812b-4678-9763-34c9da2d761e	+261342307565	Madagascar	+261	$2a$10$fQJEZ0tYHGWnm7Xdu7F/9.Bg84pFeDVNO.mq9IWk5LwpeIT/xvrSy	2026-04-05 16:26:28.313	0	2026-04-05 16:21:29.068	2026-04-05 16:21:28.314	2026-04-05 16:21:29.069
952964fa-ef22-4556-a205-1ee813e46cca	+261342307565	Madagascar	+261	$2a$10$K21bIq9brmFzlKhlyLcXZeHiSoPnVNN1CKolmIJltTteBEWRLmJNy	2026-04-05 16:37:12.739	0	2026-04-05 16:32:12.993	2026-04-05 16:32:12.74	2026-04-05 16:32:12.994
6516a9e7-7c45-4151-9f5c-bb3d1d6e0638	+261342307565	Madagascar	+261	$2a$10$Tc5WWIe/MOw3vwYC0.0Dgussd3doM/i8p3qB8ciCcObCP7b/KjhDO	2026-04-06 13:20:47.923	0	2026-04-06 13:15:48.467	2026-04-06 13:15:47.926	2026-04-06 13:15:48.469
6df8760c-9744-425a-b0b0-ba28f7b675cb	+261349459128	Madagascar	+261	$2a$10$.LbxZZGoWdpmn/cAnmY01.2Gbm1vN.IaDSuacFdv8Qd3eewAL5agO	2026-04-06 13:59:53.034	0	2026-04-06 13:54:53.455	2026-04-06 13:54:53.036	2026-04-06 13:54:53.457
5122b5c9-ae13-4202-8292-480a1d04b959	+261349459128	Madagascar	+261	$2a$10$54UM5yc/YdfoR1GzZYcFXOzjwes7VR7EJe5w1MLAoRdDCC/GO9b4a	2026-04-06 14:56:52.283	0	2026-04-06 14:51:52.737	2026-04-06 14:51:52.284	2026-04-06 14:51:52.738
1b962f4f-dbcc-4ec6-ba9f-dde3b4faace9	+261349459128	Madagascar	+261	$2a$10$Vp5hm7v4YsQfA73GY83TleaMLABGI2woi2dRLcQ.o5cKf5l8BlYku	2026-04-06 15:15:00.888	0	2026-04-06 15:10:01.524	2026-04-06 15:10:00.889	2026-04-06 15:10:01.525
2f6e85d4-0c96-4c11-867e-ba7b3c853a86	+261349459128	Madagascar	+261	$2a$10$TOAdAMyPtX4td3R8guHFLehOGAKpScauNJlGD2Vs6ugbFiGRSFLKy	2026-04-06 15:50:13.478	1	2026-04-06 15:45:23.97	2026-04-06 15:45:13.479	2026-04-06 15:45:23.971
389ae9e3-6984-4691-b704-2c9c949a037d	+261342307565	Madagascar	+261	$2a$10$1zGwzkJ7FxwDSo1yhrzgAuOMzlaU1Y3z1ImydRTtR8znQcTAr9Ddm	2026-04-06 16:14:59.698	0	2026-04-06 16:10:00.016	2026-04-06 16:09:59.699	2026-04-06 16:10:00.017
5141bfd2-9131-4858-b9a3-3a99ec76578f	+261349459128	Madagascar	+261	$2a$10$ulqslUUfKF/4x3OIGuA6Ru9zxEUzX3YY.yteeQQOCe0Smxa5kcvAu	2026-04-06 16:15:39.861	0	2026-04-06 16:10:40.139	2026-04-06 16:10:39.863	2026-04-06 16:10:40.14
9efd3b4f-34f8-4e11-83a8-427bd0fcc83e	+261342307565	Madagascar	+261	$2a$10$hiaXojHZOMjS7IG13w9x9.CcvZlzikQKAPFNctkIMhssTAasdLUaK	2026-04-07 15:18:12.448	0	2026-04-07 15:13:13.194	2026-04-07 15:13:12.451	2026-04-07 15:13:13.196
e21351dd-43b5-46c5-a086-eb60b0fa79c3	+261349459128	Madagascar	+261	$2a$10$v7BGwne12BCqTuFW8UWoQuiJBY3jS.EMpIzSLfH7RDIRmDgmyazKu	2026-04-08 00:54:56.603	0	2026-04-08 00:49:57.166	2026-04-08 00:49:56.605	2026-04-08 00:49:57.168
aa32c9cb-ccbb-49c8-8d15-c3d22a8678fb	+261342307565	Madagascar	+261	$2a$10$cOuVCE9ocRQO1RCJq/mqKeNud5t.Wa8wl.R0Bdl9lAyJjMtjGFQlK	2026-04-08 00:57:17.292	0	2026-04-08 00:52:18.158	2026-04-08 00:52:17.294	2026-04-08 00:52:18.16
36ba7b58-8169-459a-86aa-48badaa2dcac	+261349459128	Madagascar	+261	$2a$10$X3c1z1RUKciXaA2IpUkiUOFdL4Uq9pIb4DUlJHYEURahwVPFwAqtm	2026-04-08 09:53:11.042	0	2026-04-08 09:48:11.569	2026-04-08 09:48:11.044	2026-04-08 09:48:11.57
d4fd737f-611b-412c-896a-800d5cd2908f	+261349459128	Madagascar	+261	$2a$10$dchLpAakBeH8g08pxLPA9uc7tJDUjsFBW.3i9JJwmRWonpVA7UXQK	2026-04-08 15:15:56.66	0	2026-04-08 15:10:57.076	2026-04-08 15:10:56.662	2026-04-08 15:10:57.077
52a2ea53-aecc-4dac-8ff6-f257c13e369b	+261342307565	Madagascar	+261	$2a$10$usOcdRo.hpmMdVvi66SnZeVdL1jZjihAV9PrFpAmGbtpU10ky93E6	2026-04-08 15:44:43.982	0	2026-04-08 15:39:44.325	2026-04-08 15:39:43.984	2026-04-08 15:39:44.327
73b9bba5-f835-40ac-b0d8-ee9de3694daf	+261349459128	Madagascar	+261	$2a$10$Qfo8aooIGZ045c2ZgLROauBAfV.lDMni7EeW8Q0I2fJTtFUGhE7Ue	2026-04-08 15:45:17.186	0	2026-04-08 15:40:17.597	2026-04-08 15:40:17.187	2026-04-08 15:40:17.599
733dc386-f761-47d2-9aab-d22c843e0e55	+261342307565	Madagascar	+261	$2a$10$N6wDZWzPmW4ajbrkMlS2e.0Az3DLNmhMd2X0HcZpsbeBv9CZIFGne	2026-04-08 17:52:55.15	0	2026-04-08 17:47:55.544	2026-04-08 17:47:55.151	2026-04-08 17:47:55.545
e511bf43-8bc5-47a4-b6b0-8c3782a163fe	+261342307565	Madagascar	+261	$2a$10$l.9/j3D8aGzX1rA8bv1X/eKQ0nJF8nKDtRZ2Y9olVw6MuRPGoM4Wi	2026-04-09 16:28:54.528	0	2026-04-09 16:23:55.071	2026-04-09 16:23:54.529	2026-04-09 16:23:55.073
bb05864f-e76f-4cd0-bc7f-a9f7163e16de	+261349459128	Madagascar	+261	$2a$10$K6/TCuH8ruQHKhiC2gCsNunA9AMvriW1yulEzZWD8jggDpGUxJEuW	2026-04-11 14:27:34.983	0	2026-04-11 14:22:35.521	2026-04-11 14:22:34.988	2026-04-11 14:22:35.523
19fe8ddd-4900-4acb-9d63-d61a6e7cf412	+261349459128	Madagascar	+261	$2a$10$bJ3DcTmAJrGuP50fahwuTOjzWMZQUP1Ay8.dwa5EPmY5Y3icCSi9y	2026-04-11 21:47:58.054	0	2026-04-11 21:42:58.553	2026-04-11 21:42:58.057	2026-04-11 21:42:58.555
01fd5e95-b678-4a8b-9ee9-6506200a04bb	+261349459128	Madagascar	+261	$2a$10$liVvC.vgz6c.UOQzZTohbeB1XXhY.QKqHDKcR9ycQzofL8fK5bI82	2026-04-13 07:55:18.952	0	2026-04-13 07:50:19.85	2026-04-13 07:50:18.955	2026-04-13 07:50:19.852
72377217-932c-4882-94e2-14a425127fb6	+261341234567	Madagascar	+261	$2a$10$JY3ZM8cZtJXMTqvXfZWPpeFHhWNHJomVbTgKSicriqrMcNdiaVRem	2026-04-13 08:21:00.008	0	\N	2026-04-13 08:16:00.01	2026-04-13 08:16:00.01
c28a2335-4d4e-400f-bfd1-b097a6ee594c	+261342307565	Madagascar	+261	$2a$10$cuACiv1zoeyIAfGens4L0.YaNJIwPj.Ja6FrzUHCIlgxN1CVSK.wO	2026-04-13 08:23:53.304	0	2026-04-13 08:18:53.597	2026-04-13 08:18:53.306	2026-04-13 08:18:53.599
b521a33e-2742-4eb8-8c86-6417eb1736d7	+261342307565	Madagascar	+261	$2a$10$z8wFztw4ifPSVEfKgQcsz.lTeVnwHAnXtOMSsCYLFwXcArWHIN35C	2026-04-13 08:39:48.825	0	2026-04-13 08:34:49.415	2026-04-13 08:34:48.827	2026-04-13 08:34:49.417
8762310a-7b56-4329-88f9-d35d8431f138	+261349459128	Madagascar	+261	$2a$10$ziN8en0b49HoquqASqHcyuyPf/cpLNVvSRCwuQZOvC/PaHrGQl6jS	2026-04-13 15:46:20.35	0	2026-04-13 15:41:20.923	2026-04-13 15:41:20.351	2026-04-13 15:41:20.924
ce80eb52-9097-426d-ba63-6b3dd9b93c41	+261342307565	Madagascar	+261	$2a$10$QLGuUhX2Uufk/2IxWPzx..hs6quFF5ATNW1ic0B4gDntrUZrZBQq.	2026-04-13 15:48:29.898	0	2026-04-13 15:43:30.35	2026-04-13 15:43:29.9	2026-04-13 15:43:30.351
a7f6fffc-c968-4052-87bf-4d1d35714297	+261349459128	Madagascar	+261	$2a$10$94d5.w1zsrg3wuidbb5Ra.R9BxqFaPzkRr9YmQ8oEbTEJg9igxTvu	2026-04-19 12:50:38.626	0	2026-04-19 12:45:40.158	2026-04-19 12:45:38.629	2026-04-19 12:45:40.16
30447440-5ba6-44d6-a09a-ac1dab6e738f	+261324965862	Madagascar	+261	$2a$10$.K3NQ/niCDqfJgKra6xPhO3vl3L8B2zATg6yg9l2Pg/TeKMDb0LuO	2026-04-19 16:10:56.831	0	2026-04-19 16:05:57.381	2026-04-19 16:05:56.833	2026-04-19 16:05:57.382
fa9fe605-a1c4-4115-aad7-959c2dff5b69	+261342307565	Madagascar	+261	$2a$10$Dk8NhWknAVQFo032UnhQwezXrnxKpsGuyqU4b4p1oqW/qFWhey4Gi	2026-04-20 16:50:23.177	0	2026-04-20 16:45:23.593	2026-04-20 16:45:23.178	2026-04-20 16:45:23.594
cf85b34f-616f-46d8-8723-7ee938bffc4f	+261349459128	Madagascar	+261	$2a$10$ZS748L1HNrhukx4o/7iH3.kBvUzMIIU9LdOjB2rPosGMjVZZyi6HK	2026-04-23 23:59:38.432	0	2026-04-23 23:54:39.635	2026-04-23 23:54:38.434	2026-04-23 23:54:39.637
cb0fb3d2-d3d0-4dc7-9ce7-63dbae1329a8	+261349459128	Madagascar	+261	$2a$10$49SSkHf3d9JvcMXmK47ageR4p98jbrnKVhfCfrb5omAJjgQWRJkEi	2026-04-24 00:34:14.514	0	2026-04-24 00:29:15.299	2026-04-24 00:29:14.515	2026-04-24 00:29:15.301
45b0fcc2-92d3-461f-ae12-fed1d1f63b1f	+261342307565	Madagascar	+261	$2a$10$2apSuOk7tG.a2pytpU.qKOmJ.ZZIKVIvFdNii5fwAcBcvOVf3nExC	2026-04-24 04:15:28.364	0	2026-04-24 04:10:28.645	2026-04-24 04:10:28.366	2026-04-24 04:10:28.646
19173a8d-4042-46b5-a748-7ffe981cbd92	+261349459128	Madagascar	+261	$2a$10$zgEBKh9EsoeDXZnztjPGiue3DShKiyfZKAx6pc.AkD01o2I8LcXoG	2026-04-24 05:07:44.564	0	2026-04-24 05:02:45.419	2026-04-24 05:02:44.566	2026-04-24 05:02:45.421
e79c4cc2-280b-4a37-9149-3b6c583ea199	+261342307565	Madagascar	+261	$2a$10$EH/FDheJArVzKP7IfHW0oeuk2pXfEGFGDX0GH5NI6L28ZmwjvM6Qi	2026-04-24 05:09:34.347	0	2026-04-24 05:04:34.878	2026-04-24 05:04:34.348	2026-04-24 05:04:34.879
2b2b6381-dac9-4335-8088-cd06c795ef55	+261342307565	Madagascar	+261	$2a$10$B5cOG293hZXKCBgRYDZTnOE6gbP8Gv0b/vna62/UOyrPAxw3dA8D.	2026-04-26 03:51:59.382	0	2026-04-26 03:47:00.16	2026-04-26 03:46:59.383	2026-04-26 03:47:00.161
00699727-2892-4602-bebd-4754357dfa61	+261324965862	Madagascar	+261	$2a$10$CQ4qWhWFbbrhtiAhdl2S..SO9ndOWPLRq5JyOFHyyRUNxCdquY.fy	2026-04-26 09:49:25.889	0	2026-04-26 09:44:27.475	2026-04-26 09:44:25.896	2026-04-26 09:44:27.476
2cc2802f-0430-472e-950a-bd2f73d1fb4d	+261340258202	Madagascar	+261	$2a$10$Ag.8eX0qdRfGXGm.P.P1/uMsbM8qeFaKy6NV5wl4Vbu0xTgO84VaK	2026-04-26 09:54:14.452	0	2026-04-26 09:49:14.99	2026-04-26 09:49:14.453	2026-04-26 09:49:14.991
16f5cae1-5b53-4aad-a084-ec5bf494ce6a	+261340258202	Madagascar	+261	$2a$10$HsoEkQiIXGDOG8mvnVrVGOi0cX41e836HkAdRLf3JwS9ywsYjOQVq	2026-04-26 09:55:26.252	0	2026-04-26 09:50:26.47	2026-04-26 09:50:26.253	2026-04-26 09:50:26.471
2de2e73d-432b-4a7b-b7ee-d769592b7613	+261342307565	Madagascar	+261	$2a$10$n48s87wZ2pVh2cwhfOSpA.SClpiUtSmZZaxMKXKTutrrWJYyFBOMS	2026-04-26 13:31:02.185	0	2026-04-26 13:26:02.802	2026-04-26 13:26:02.194	2026-04-26 13:26:02.804
925f6b52-88d6-4a4d-9882-657bcd03cf46	+261342307565	Madagascar	+261	$2a$10$NHliykvjgIF/GuC0qOlwoOwKfGJUwJJyfiKfiuv6/D2aaY3KkxXe6	2026-04-26 14:05:42.315	0	2026-04-26 14:00:43.012	2026-04-26 14:00:42.316	2026-04-26 14:00:43.013
15a0ca44-5d37-455f-9881-423ea053080e	+261349459128	Madagascar	+261	$2a$10$AvocgK956d/Lbq3nZGPDvuXoZHREyqCCWSXENLe2VFqyy9nlz5OCe	2026-04-26 14:16:59.5	0	2026-04-26 14:12:00.236	2026-04-26 14:11:59.502	2026-04-26 14:12:00.238
0b3d329b-5210-427c-8057-aa7fe4ed3594	+261349459128	Madagascar	+261	$2a$10$Fps/uGeeta0WZ4WveBZuWu2d2WfdrtWithpxldcgsmyMDwZVCFRni	2026-04-26 14:28:55.264	0	2026-04-26 14:23:55.913	2026-04-26 14:23:55.266	2026-04-26 14:23:55.915
60ea5a60-ba19-4f80-8d22-15ce4c8bc55b	+261342307565	Madagascar	+261	$2a$10$RPYyBprKic79oVP6.qpqaeb9dXjoefuEQy.BwRSFy.u7SFH4/u.9S	2026-04-26 14:40:00.9	0	2026-04-26 14:35:01.426	2026-04-26 14:35:00.901	2026-04-26 14:35:01.428
ca3f589a-0764-402b-a600-9c9fbea79cf9	+261349459128	Madagascar	+261	$2a$10$4mSoigmVpn4K6VdPHMg83ejuTMbjELeu5gQSfd3Xr/vXXPRar7VSS	2026-04-26 14:44:38.203	0	2026-04-26 14:39:39.05	2026-04-26 14:39:38.205	2026-04-26 14:39:39.051
cfc4dbd1-ccfe-4b14-a5a9-45aa25faf317	+261349459128	Madagascar	+261	$2a$10$v2PVPn2hT/fSx76LGiF2k.XARLl4hqWDoJYTsIKNn6/hX1J2T1ElC	2026-04-26 14:51:09.903	0	2026-04-26 14:46:10.712	2026-04-26 14:46:09.904	2026-04-26 14:46:10.713
2c4aa7c1-e156-46fe-b7e0-0c078584d46d	+261342307565	Madagascar	+261	$2a$10$IgeB1g2.yphzT4inreVO.eLHDdoXqcs8tS/MfHB.UKtbjGfd7b9Ti	2026-04-27 17:11:10.674	0	2026-04-27 17:06:11.287	2026-04-27 17:06:10.677	2026-04-27 17:06:11.289
fa2c99fc-64fb-4dab-bc20-7d025cd993f5	+261342307565	Madagascar	+261	$2a$10$H/vSoNpKeYQZvltQUwJbpeNUbt0lv20OwdlB.8FoDQirI./y8h0xu	2026-04-27 17:12:22.527	0	2026-04-27 17:07:23.187	2026-04-27 17:07:22.528	2026-04-27 17:07:23.188
e7ce1fad-144b-4532-bf98-cf1d78e516cd	+261349459128	Madagascar	+261	$2a$10$K0HM64E60dpTrP20lMDha.Y72AcKmIvOmSbSxlfUUI8BzZnYp/pJe	2026-04-27 17:18:40.231	0	2026-04-27 17:13:40.652	2026-04-27 17:13:40.232	2026-04-27 17:13:40.653
3b555f85-ab1f-4d13-8294-9229cc435e55	+261342307565	Madagascar	+261	$2a$10$rzgRQ7SNWc8GM.3E2o4LlOoyzivvCbo6bBSx6/.F3qZKYKpgbpaTq	2026-04-28 20:52:12.635	0	2026-04-28 20:47:12.842	2026-04-28 20:47:12.637	2026-04-28 20:47:12.843
e3a96e1c-ec70-4992-8a30-7636b087da03	+261342307565	Madagascar	+261	$2a$10$XVfgQ4I9Rw4TlR.rtJl43Oy4AVNoIYdEoJqQl7llTHMbpCewZvvyS	2026-05-05 15:36:35.525	0	2026-05-05 15:31:36.525	2026-05-05 15:31:35.527	2026-05-05 15:31:36.526
9b0bb46d-7688-4905-97dd-c01e6b40ffb6	+261324965862	Madagascar	+261	$2a$10$5jzsAtHlWHjudIFbc8yLGOW6n4VCs1m5IJ0Opi3idIAIUwKyY5a7q	2026-05-05 16:44:29.223	0	2026-05-05 16:39:29.602	2026-05-05 16:39:29.225	2026-05-05 16:39:29.603
c7771d26-14cf-4a88-8381-ef64644a3349	+261342307565	Madagascar	+261	$2a$10$EtlnSr3OsOhxOQw4hSYDl.kwFDZSKrwkVJ0m1.kjvRwBvt4s.xkyi	2026-05-05 16:44:41.865	0	2026-05-05 16:39:42.858	2026-05-05 16:39:41.867	2026-05-05 16:39:42.859
88b84237-7182-4c02-bd5d-2a12a11745c4	+261324965862	Madagascar	+261	$2a$10$aMGPEXuEFUi1e7Kjo2RgWODsz8188ADT7rpuZPsykDmB32H4Hnf6q	2026-05-05 17:09:46.517	0	2026-05-05 17:04:46.866	2026-05-05 17:04:46.519	2026-05-05 17:04:46.868
77dffee6-b6fd-4da1-8ecd-b7c1d5307daa	+261349459128	Madagascar	+261	$2a$10$LCFCH.UBTQvEzfxc6nTBi.FI8/AWb3YtDwmlyRG6VHXWk6mZYeqtW	2026-05-05 17:50:10.713	0	2026-05-05 17:45:11.036	2026-05-05 17:45:10.714	2026-05-05 17:45:11.037
a449804f-a2f4-4da4-a21b-a27a301c95d3	+261349459128	Madagascar	+261	$2a$10$OcQUr54qzdb63OPtShkOiu9XQDP2vtrICpbPA02ibKqpj4zAXnz0C	2026-05-06 16:40:12.988	0	2026-05-06 16:35:13.596	2026-05-06 16:35:12.989	2026-05-06 16:35:13.597
4d12285e-3cea-4ff0-a13f-9855795acc1a	+261320365103	Madagascar	+261	$2a$10$u5KG7ZiJU/.Xxx/UnB2D1uDQOIt.dpVmC9HaJbn0Q0M2dtAxnRBnS	2026-05-06 16:41:28.581	0	2026-05-06 16:36:28.82	2026-05-06 16:36:28.583	2026-05-06 16:36:28.822
dded6a5a-7320-433b-8260-1cca0c5eea96	+261349459128	Madagascar	+261	$2a$10$byaKAWC3z9NxCt9q3Zbf3uORKDwq377XY4KdZWp7ZGmqrdF6tFGZ.	2026-05-06 16:54:58.554	0	2026-05-06 16:49:58.988	2026-05-06 16:49:58.556	2026-05-06 16:49:58.989
78739a11-3c53-425d-a611-768381d4dcf1	+261342307565	Madagascar	+261	$2a$10$.Qn9fuMbDjSZmtdiZt3BVe6SCM.DdqwIW76YsqesWkbNUcTIAwQlO	2026-05-06 19:18:20.418	0	2026-05-06 19:13:20.909	2026-05-06 19:13:20.42	2026-05-06 19:13:20.91
8b31d448-8732-4fad-ad12-6c5f65536ad8	+261349459128	Madagascar	+261	$2a$10$ftWE0NR085iXaNLzT2A30e9P2eG6ZKDypb.182cajOs1GdrHnvIj.	2026-05-06 19:52:49.146	0	2026-05-06 19:47:49.783	2026-05-06 19:47:49.148	2026-05-06 19:47:49.785
193ab32a-83cc-4299-a2e9-8876ec092db0	+261320335103	Madagascar	+261	$2a$10$GHHnMYTgYcIkN.il0YSrp.3zDlXdNo7C0xvqWclE.IdweMi79IzxG	2026-05-06 19:54:00.848	0	2026-05-06 19:49:01.346	2026-05-06 19:49:00.849	2026-05-06 19:49:01.347
d0a4026c-2f99-4332-9659-daeba3b571ce	+261320335103	Madagascar	+261	$2a$10$Z9FoBujGsHcfDHnKMWrPcOrI87bLYUDNTDGdsuaYDNrooEy2FXx2W	2026-05-06 19:54:58.575	0	2026-05-06 19:49:58.786	2026-05-06 19:49:58.576	2026-05-06 19:49:58.787
2c84d1bd-4c3e-4554-8044-0736cc4e8b4a	+261320365103	Madagascar	+261	$2a$10$.kIy6L7JB/Ul0kpYwO.l4.JppP2W3rIz0VOLGjd87H4LpwmuBCvd2	2026-05-06 19:56:39.227	0	2026-05-06 19:51:39.44	2026-05-06 19:51:39.228	2026-05-06 19:51:39.441
ce316ada-baae-497f-9e16-6d6c254c34d1	+261324965862	Madagascar	+261	$2a$10$6Kx9OgjgBr3.guZHsm536OVkDloljS2fTamcQrYo/OQ.NjGz/S.yK	2026-05-07 02:16:45.282	0	2026-05-07 02:11:45.869	2026-05-07 02:11:45.285	2026-05-07 02:11:45.871
28e2bb7b-bb55-4bd2-b41c-408effba0fa6	+261349459128	Madagascar	+261	$2a$10$P2LuW.2XHox.Tc59v9oJVu2rLTvBodw0k3twFn7oRh8JPetnsJmYu	2026-05-07 02:23:42.758	0	2026-05-07 02:18:43.025	2026-05-07 02:18:42.759	2026-05-07 02:18:43.026
b6e27f46-dffd-44a1-b170-96c27969c075	+261320365103	Madagascar	+261	$2a$10$yMf8nZts.jJUP8BoIGmEseeAAd.KupXAZO3Mloo8YdEDaiu163S9.	2026-05-07 02:26:24.678	0	2026-05-07 02:21:24.948	2026-05-07 02:21:24.679	2026-05-07 02:21:24.948
0fb69da6-a2ad-4e58-a8fd-85080e76c7b6	+261349459128	Madagascar	+261	$2a$10$KkzpRCJh1.GjAzfXyg2RXOdjz2MY9YzIHBraDbxddaxrP7D2nB8CW	2026-05-07 02:26:47.929	0	2026-05-07 02:21:48.145	2026-05-07 02:21:47.93	2026-05-07 02:21:48.146
16b1f959-cc5d-4a17-bdc3-baf0e6c06f21	+261342307565	Madagascar	+261	$2a$10$qQvtOHLdT5YVuz5w4f/gC.hg5noiPqMDS/8zduyT4dgjKGs9coiyi	2026-05-07 19:03:58.58	0	2026-05-07 18:58:59.073	2026-05-07 18:58:58.582	2026-05-07 18:58:59.074
296b5a67-a539-4c07-987e-45e09c7bc736	+261342307565	Madagascar	+261	$2a$10$QNYZ2Gsz01o099bQheW1SuyNoni9VEqKiSW1m/b9cgZuLJYnWWb72	2026-05-09 15:30:44.034	0	2026-05-09 15:25:44.774	2026-05-09 15:25:44.268	2026-05-09 15:25:44.775
5dc88974-8700-481d-af50-b3db8839779b	+261342307565	Madagascar	+261	$2a$10$T9Dmr95nds1Euku4JZWoWu6eORivQ2iBBAzyFYypbQ43SzFL4cn06	2026-05-09 15:39:08.79	0	2026-05-09 15:34:09.53	2026-05-09 15:34:08.791	2026-05-09 15:34:09.531
dc866cf7-fb9d-490b-ad91-3c26afc74b03	+261342307565	Madagascar	+261	$2a$10$cYa9V.69x0doDmSgtcjSAOQXq6jaZouuf6kdrp71W372EtrhdDny2	2026-05-09 15:41:25.381	0	2026-05-09 15:36:25.603	2026-05-09 15:36:25.382	2026-05-09 15:36:25.605
0c8a15d3-6d05-4ee3-9e6b-9013e7030289	+261342307565	Madagascar	+261	$2a$10$mIZyP6lbt1fnflCHZfBHeuOHvUmAuJVQRPLVlqVdVDyatFzbnS3nm	2026-05-09 17:31:21.119	0	2026-05-09 17:26:22.02	2026-05-09 17:26:21.121	2026-05-09 17:26:22.021
40bb4dcf-18ea-4504-b7e2-e84eb9c96990	+261349459128	Madagascar	+261	$2a$10$VQiEpNP1ARmrtRYrF41QVOWud4oT805ixbnXN4mltfHcCA4WpIiAi	2026-05-09 17:48:17.216	0	2026-05-09 17:43:18.203	2026-05-09 17:43:17.217	2026-05-09 17:43:18.205
6c80f35a-65fc-4b2f-8f2b-171a974ee784	+261342307565	Madagascar	+261	$2a$10$BEYH5VZX5/IpgcdtDkqNEe67SbzJMFsUiCviryz7gowrg2BUnRcBO	2026-05-09 18:13:51.063	0	2026-05-09 18:08:51.447	2026-05-09 18:08:51.064	2026-05-09 18:08:51.449
01d2086d-28db-4291-b4ec-9a2e5e092dd2	+261342307565	Madagascar	+261	$2a$10$8zIvFwsi8CF2MdYZzHxd0u7vjtdKpz.GNKGYFpGCvHIjQN9DzZR1q	2026-05-09 20:00:01.187	0	2026-05-09 19:55:01.573	2026-05-09 19:55:01.189	2026-05-09 19:55:01.575
b6a2ba28-2553-49c8-86bb-140e73808bcd	+261342307565	Madagascar	+261	$2a$10$cCvo7KULxU/BFWa3E8ZjL.B1fsZ6QypZiZuloRBg8roPr8oE1sloW	2026-05-09 22:42:53.065	0	2026-05-09 22:37:53.424	2026-05-09 22:37:53.067	2026-05-09 22:37:53.426
e10728d5-cbe2-4f15-9751-8c2467afa580	+261346349868	Madagascar	+261	$2a$10$iaZR07ibln4qWD01m2tDoOOO4ZTpvwqDNmlaOKPHWgS1VVgMDInUi	2026-05-12 16:27:08.612	0	2026-05-12 16:22:09.06	2026-05-12 16:22:08.613	2026-05-12 16:22:09.061
5d5c6f8e-92f8-487e-9228-adb09cf69294	+261346379868	Madagascar	+261	$2a$10$bamqxbbma892d7X8qspYoOlAu0cKuWDvRqNQGOxpBJmdiXOSkVNAm	2026-05-12 16:27:23.073	0	2026-05-12 16:22:23.324	2026-05-12 16:22:23.074	2026-05-12 16:22:23.325
6fefc58d-dbe9-40d8-8eff-93b6a201043a	+261342307565	Madagascar	+261	$2a$10$8uXtIsM8GzSib938oWtbbOGoL4kOmq3dFOqIetNOVIaAYLFVSY2Wa	2026-05-12 16:29:32.319	0	2026-05-12 16:24:32.747	2026-05-12 16:24:32.321	2026-05-12 16:24:32.752
4e7f37d1-3e81-4f01-bc74-0cdedc8438fb	+261342307565	Madagascar	+261	$2a$10$PztDJBV./FDaQgbL5Cg16eYOgSFG.GQOxgkyzd2NrmlOiEM48IidS	2026-05-13 15:11:55.135	0	2026-05-13 15:06:55.495	2026-05-13 15:06:55.138	2026-05-13 15:06:55.496
542d32ec-8e03-43ab-b287-aedb4b7ecb5a	+261349459128	Madagascar	+261	$2a$10$1NhDdRtyWh1duvSHLZp97.mwI5ZArijH6.kJpJuG8IWWOC5mk6tFW	2026-05-13 15:14:17.342	0	2026-05-13 15:09:18.116	2026-05-13 15:09:17.344	2026-05-13 15:09:18.118
7f7a9e24-dd12-43e3-b2ef-0dfa2e8e1194	+261349459128	Madagascar	+261	$2a$10$ezsF5NP/njcW1G8uMtmNkOBn7jE/Ul0K6LPvZPkWES8hLyke3y36O	2026-05-13 15:56:07.691	0	2026-05-13 15:51:09.27	2026-05-13 15:51:07.692	2026-05-13 15:51:09.271
ac74f256-94f9-4130-a4d8-9fa0b141f53a	+261342307565	Madagascar	+261	$2a$10$nqgfQYaAzOCNbzvAwkBMNu0fXaJfoCIPjGZdk6sTeSTtbGijoKCMe	2026-05-13 15:58:22.487	0	2026-05-13 15:53:22.766	2026-05-13 15:53:22.488	2026-05-13 15:53:22.768
a3d2a532-f3c2-4cb4-a951-b12e2887c31e	+261349459128	Madagascar	+261	$2a$10$JtBOvij.2pQammyv7JG/V.xphZlBbfJTfqjgfcuUpIUHzYyuC39ne	2026-05-14 16:04:55.64	0	2026-05-14 15:59:56.015	2026-05-14 15:59:55.642	2026-05-14 15:59:56.017
9aa4fe91-110d-4328-9c95-dd4b64e8da19	+261342307565	Madagascar	+261	$2a$10$pMvpE0mpd8.cftihJR2xo.w12WrbwMzlMIsVAgeD71SuFbDqnhjQK	2026-05-14 18:33:36.392	0	2026-05-14 18:28:37.38	2026-05-14 18:28:36.399	2026-05-14 18:28:37.381
4df21ee0-c4ac-4dc3-a6ad-8d04d25f8839	+261349459128	Madagascar	+261	$2a$10$YYp8NzIxvk6HiH/SCWa0oetDwLuoiUSG7VMc34FoXsejMKwsic9zu	2026-05-14 18:35:31.885	0	2026-05-14 18:30:32.408	2026-05-14 18:30:31.886	2026-05-14 18:30:32.41
ff99caae-7dd6-4beb-9561-011b261ba131	+261349459128	Madagascar	+261	$2a$10$cPYd37mZM53Iu8uOz1M7A.tqMRNVEB8Sk8JoxkFQtHgz8/Dxll09y	2026-05-14 18:37:34.254	0	2026-05-14 18:32:35.228	2026-05-14 18:32:34.255	2026-05-14 18:32:35.229
46da3cf8-66cf-43b5-b934-48a38a4a8d0b	+261342307565	Madagascar	+261	$2a$10$pvgoHZ1OV6IghczF5B5kC.PBq5TSJgStLOVgv0Iwc/9Ss.7eQhAZ2	2026-05-14 18:38:07.924	0	2026-05-14 18:33:08.202	2026-05-14 18:33:07.926	2026-05-14 18:33:08.203
ddd1d286-a256-4041-a989-fc7db7343669	+261342307565	Madagascar	+261	$2a$10$F.SaHs/U9kgdTYyfCANFKuK3Ri4x9bt23RP4mhHcRVabrIYBMP2qC	2026-05-14 19:45:26.366	0	2026-05-14 19:40:26.707	2026-05-14 19:40:26.368	2026-05-14 19:40:26.708
b907a984-7c3a-44e6-afb6-87abfc2d1c7e	+261349459128	Madagascar	+261	$2a$10$bAyH9AC/U9qG0ZyLz1RFGOaMdFjw.tqmuZJlO1idrip9tYVwluygi	2026-05-16 07:13:05.32	0	2026-05-16 07:08:06.014	2026-05-16 07:08:05.33	2026-05-16 07:08:06.016
a6fdda25-6340-4433-9120-3b33f8d054a0	+261349459128	Madagascar	+261	$2a$10$QuzqpNJYBCAHHSjVua4KiOjfiwDxqmwya0LxE2HYwoJjHR3bRx/oe	2026-05-16 07:39:09.094	0	2026-05-16 07:34:10.613	2026-05-16 07:34:09.096	2026-05-16 07:34:10.614
df800428-b873-4799-a75b-fd2a36f2443b	+261349459128	Madagascar	+261	$2a$10$eUsfn.alQeo3EYK0WbzjQO4RNug2f1vk4kNZ59bcse4zuuy5OqJqG	2026-05-16 08:11:59.726	0	2026-05-16 08:07:00.842	2026-05-16 08:06:59.729	2026-05-16 08:07:00.843
93a7a974-0950-4640-bee2-008b86a9d8e1	+261342307565	Madagascar	+261	$2a$10$5vU6f.OyRY1MjSdQo8N3semjBFJ/IKeB9qc3jM5h2Oiku4T0xYHW6	2026-05-16 14:58:21.953	0	2026-05-16 14:53:22.474	2026-05-16 14:53:21.956	2026-05-16 14:53:22.475
e55e041b-4928-40eb-9a51-3c5c2b571b56	+261349459128	Madagascar	+261	$2a$10$vcHZFbr4/X3r3lIJ9GJopexg3uTQ/j1wRaV4eL4kMVQR/HFf7nP2C	2026-05-16 14:59:49.161	0	2026-05-16 14:54:49.754	2026-05-16 14:54:49.162	2026-05-16 14:54:49.755
ada26c0c-e0d6-4fe8-8b26-645d84849aa3	+261342307565	Madagascar	+261	$2a$10$5eAywnXF4t0sqbKyHXpBp.IWtoQ125kOUo7uYrKiJ20uZdDpySNfu	2026-05-17 09:32:30.745	0	2026-05-17 09:27:31.103	2026-05-17 09:27:30.746	2026-05-17 09:27:31.104
5baa3184-8709-432e-9662-8fed2c8b3221	+261349459128	Madagascar	+261	$2a$10$lerSs7WLkrNS2RkoXVqF/e9HatmU6wGUqXydywRYgywxAdBLXemBW	2026-05-17 12:52:49.722	0	2026-05-17 12:47:50.034	2026-05-17 12:47:49.723	2026-05-17 12:47:50.035
7abb6b9f-52e9-4aaa-af89-1b5faf3cd881	+261342307565	Madagascar	+261	$2a$10$qTga2t756Z.NpvkUSkFmWev7vs0Py8EC8wbKjHybYL7ZCOIG1.PNG	2026-05-17 12:53:22.834	0	2026-05-17 12:48:24.335	2026-05-17 12:48:22.835	2026-05-17 12:48:24.336
75975e34-c99d-43bb-8dfb-0a24def2c7cc	+261349459128	Madagascar	+261	$2a$10$Mj3hFlzUgfEvuriZI2PlWetGBhOOZ6NdnQGPAG1aa37gylKGuLRae	2026-05-17 16:37:30.299	0	2026-05-17 16:32:30.808	2026-05-17 16:32:30.301	2026-05-17 16:32:30.809
1401c690-2b0b-4e6d-afc5-d8afee8dba7c	+261342307565	Madagascar	+261	$2a$10$u/Vy.N/QctKes3hkcKsS9uQ07NIZDyjGpT2F.IscLkpQr5V1qqcKm	2026-05-17 16:47:06.674	0	2026-05-17 16:42:07.04	2026-05-17 16:42:06.675	2026-05-17 16:42:07.04
5f804d45-7b53-48dd-be1c-43339679cc05	+261349459128	Madagascar	+261	$2a$10$yAwSg1pImGSj0SqjXHgZQOormM7dkoh2DizcvCJIfCG8Q8lxI1z2i	2026-05-17 16:48:10.695	0	2026-05-17 16:43:11.573	2026-05-17 16:43:10.697	2026-05-17 16:43:11.574
4c97aef7-3ff0-440d-9fec-104b6ae5c3e8	+261349459128	Madagascar	+261	$2a$10$piXe3DGkuChwFjOJZ0UDRe5wj7N3LK63KNDGJrHMe2cUBwfGA5v5q	2026-05-17 16:48:57.161	0	2026-05-17 16:43:57.352	2026-05-17 16:43:57.163	2026-05-17 16:43:57.353
aee713b0-e59a-4eff-8aea-ae4d5d52e2c2	+261342307565	Madagascar	+261	$2a$10$BA6B//pfb/5h8VOTVQwzc.gbOUttk4dOZCSWvnJr0uiPvdqNgCqum	2026-05-17 16:49:36.292	0	2026-05-17 16:44:36.563	2026-05-17 16:44:36.293	2026-05-17 16:44:36.564
88ad34ff-7f5d-445a-9cc4-74c9b16e99cc	+261349459128	Madagascar	+261	$2a$10$eWm/9ypo89hE/P6yLCO3/.37U0pWBkALUvq.UPL9jQ7ssge3uSiGm	2026-05-17 17:09:04.636	0	2026-05-17 17:04:05.039	2026-05-17 17:04:04.64	2026-05-17 17:04:05.04
25764db7-173d-43dc-b4bc-9f312921e889	+261342307565	Madagascar	+261	$2a$10$J79NdHwNGt8sye3FbT5F/uv5/NdD4d0lXr010AM2ULm91UZHS1DmW	2026-05-17 17:09:34.573	0	2026-05-17 17:04:34.824	2026-05-17 17:04:34.575	2026-05-17 17:04:34.827
e62d11f4-370e-4d4f-ade7-638cd55240b6	+261342307565	Madagascar	+261	$2a$10$NlbnLowSoAEBfpBCaIwBPew.0bFTWijsORpPMUqgzp7UvsNsYCoZu	2026-05-17 19:16:21.319	0	2026-05-17 19:11:22.341	2026-05-17 19:11:21.32	2026-05-17 19:11:22.342
e064422c-d368-4c75-8948-8e9b95e97a28	+261349459128	Madagascar	+261	$2a$10$DoRdfRlVFtxd10ontZxVnOkrX9V10JRNSEIIpttwXs6h0QJzwSk7m	2026-05-17 19:17:47.858	0	2026-05-17 19:12:48.256	2026-05-17 19:12:47.859	2026-05-17 19:12:48.257
8d6abdfa-1634-45ce-9e54-21f216812877	+261342307565	Madagascar	+261	$2a$10$0s5vGxJHfnHTbyOku/QY/.L8t9spNnxoN23/H50gUFlTcYaSnzqGq	2026-05-18 01:20:55.282	0	2026-05-18 01:15:55.597	2026-05-18 01:15:55.285	2026-05-18 01:15:55.599
6385e279-7800-4ec3-9e90-c5c74cc90cd4	+261349459128	Madagascar	+261	$2a$10$grRo.Hqf.HTj75fN1huT1u6LOhyWWP0DOksou/fawdcs9z7W4cJhq	2026-05-18 01:34:21.635	0	2026-05-18 01:29:22.837	2026-05-18 01:29:21.637	2026-05-18 01:29:22.838
40322a9a-21a5-4cbd-a878-8216e3dda894	+261342307565	Madagascar	+261	$2a$10$loNWGad2NZ.f2XWeMpErDefyjEeHsMNxPa3eYpcL3y8lQuNIhzmdW	2026-05-18 01:45:10.117	0	2026-05-18 01:40:11.125	2026-05-18 01:40:10.118	2026-05-18 01:40:11.126
a52a33b1-022e-4ed2-b90a-e1039487ca9c	+261349459128	Madagascar	+261	$2a$10$wHKW9IVVfdiJuw2NNID67eip8lmRtr5a5XZVbsGOBIR3gLeFiqIUC	2026-05-18 01:47:10.522	0	2026-05-18 01:42:11.001	2026-05-18 01:42:10.523	2026-05-18 01:42:11.002
edbb9018-faf1-419d-8844-b9031e70c92b	+261349459128	Madagascar	+261	$2a$10$7PHu239i1M0LPZxQP4Pc9eM2C1UiJsTJtCRsU/KZODHYlQjK9ac1O	2026-05-18 09:45:04.989	0	2026-05-18 09:40:05.376	2026-05-18 09:40:04.992	2026-05-18 09:40:05.377
6b7b11e7-db10-4d04-8174-a063281e5fee	+261342307565	Madagascar	+261	$2a$10$58LAD4O8g..nfsTkLnCa0.jmZRry2kHy3B1wZfjtmIJYvXpKI7aR2	2026-05-19 04:09:14.065	0	2026-05-19 04:04:14.488	2026-05-19 04:04:14.067	2026-05-19 04:04:14.49
5e655f29-7b3e-411f-897a-048058ef1ca0	+261349459128	Madagascar	+261	$2a$10$dj0AjTBsmNJaA8l8tTH3Gu1wVvmpc.BhOiC0uyYL9hbWvEC0tolD.	2026-05-19 15:11:33.059	0	2026-05-19 15:06:33.483	2026-05-19 15:06:33.062	2026-05-19 15:06:33.485
842b2e74-97ce-4805-b909-203c090761ec	+261349459128	Madagascar	+261	$2a$10$wET2lVvW78fcoiWL.V4yoONk6H1lgwpnKTJRh5qpiM1g32Dm1hAUW	2026-05-19 18:00:51.157	0	2026-05-19 17:55:52.157	2026-05-19 17:55:51.158	2026-05-19 17:55:52.159
9c5e043e-b10d-47d4-b0ac-49edad125970	+261342307565	Madagascar	+261	$2a$10$zHvIO7N/l5D397JrhQCbIeCQIZ5H7fw/vT23g/oB2Znq1uc2jd24W	2026-05-19 18:33:43.031	0	2026-05-19 18:28:44.074	2026-05-19 18:28:43.033	2026-05-19 18:28:44.075
ff825b22-4cc1-4f24-92c3-b9e90b587030	+261342307565	Madagascar	+261	$2a$10$0SofMfYjsBUfYCAAn5DIuOFybW1f/ky9n1TBsaIKq75P6/3IfC7o6	2026-05-19 20:40:40.765	0	2026-05-19 20:35:41.763	2026-05-19 20:35:40.767	2026-05-19 20:35:41.765
732049aa-0222-4f0d-a10c-40b082f4735e	+261342307565	Madagascar	+261	$2a$10$QISdNz4XEpi7eM.Ekr4IBuSs.9QoQPhmskh2NIKwVtvrMPrFyAX5G	2026-05-22 01:56:08.352	0	2026-05-22 01:51:09.241	2026-05-22 01:51:08.355	2026-05-22 01:51:09.244
590de06f-f7c6-4f3c-8ac6-68f4a2961ca8	+261349459128	Madagascar	+261	$2a$10$g7WEprfyA8ImWYtGXELzyua7nF6NUZgkgZ7EWnxJOtqODKfqVKFQ2	2026-05-22 01:58:51.861	0	2026-05-22 01:53:52.044	2026-05-22 01:53:51.862	2026-05-22 01:53:52.045
f891141a-3d69-4c10-99db-8593ebf7b013	+261349459128	Madagascar	+261	$2a$10$e88C02XOVLdpkcomQmcneOTG4iQ/Bon/lqolRM0YEmvtgkP97S3ia	2026-05-27 08:28:07.825	0	2026-05-27 08:23:08.522	2026-05-27 08:23:07.833	2026-05-27 08:23:08.524
1e257a50-2ab7-4a7a-a467-2597272c02c6	+261342307565	Madagascar	+261	$2a$10$EJS8KZ6qtcCm4dw.ggbsFO6aaZgrIptSB6C8yp7ynq9xv5RilU4LO	2026-05-27 15:50:19.008	0	2026-05-27 15:45:19.585	2026-05-27 15:45:19.009	2026-05-27 15:45:19.586
b5f0abb3-6c8d-45c6-b406-91b78ac67c03	+261342307565	Madagascar	+261	$2a$10$9uXz4Ol/yxW2z7B6Jug9aOVoLV98Ag38RR1YrRe4SAedyO2ivlZLW	2026-05-29 18:38:13.181	0	2026-05-29 18:33:13.618	2026-05-29 18:33:13.183	2026-05-29 18:33:13.693
d35e2f37-5097-4e5b-900e-cc8e17462226	+261349459128	Madagascar	+261	$2a$10$DPW7e.w8I2RENI..8nnZp.Pm/qaMDxHrsezOtG4cxXUL4uHtmkTgW	2026-06-01 16:45:53.391	0	2026-06-01 16:40:53.858	2026-06-01 16:40:53.393	2026-06-01 16:40:53.86
fb8cd244-1cad-4211-9ba5-c58337a8b4a6	+261342307565	Madagascar	+261	$2a$10$PHVnLXxwyCEdfJxsAgzu3ubpvcmyCOZyt9tJkx1IuKojSN0QV9eHC	2026-06-01 16:46:14.523	0	2026-06-01 16:41:15.624	2026-06-01 16:41:14.525	2026-06-01 16:41:15.626
5b1c9657-b01b-4df5-a7a1-2d089a7f8fc9	+261342307565	Madagascar	+261	$2a$10$tqOCJx0NiUMD72qISy1VSuefH5a0TX8gc4MnxhJP0ctDyDf3WlKLi	2026-06-01 18:21:38.306	0	2026-06-01 18:16:39.322	2026-06-01 18:16:38.309	2026-06-01 18:16:39.324
2823ab06-656f-4354-b280-3dd3512d0e68	+261349459128	Madagascar	+261	$2a$10$/V7WbIboI3o2Vcyzw4vqK.B.bM8i6PLZGNHTAGWvAhW8reJokZWLe	2026-06-01 18:28:39.315	0	2026-06-01 18:23:40.283	2026-06-01 18:23:39.316	2026-06-01 18:23:40.284
5a1f8c59-0c95-4053-b798-41ddd05687e5	+261349459128	Madagascar	+261	$2a$10$cHo0gd/WF/8ezzUjAcyf9.Bgo4YaFZRyQV7ls78oLgDj7h9k5v.C2	2026-06-01 20:27:00.893	0	2026-06-01 20:22:01.533	2026-06-01 20:22:00.907	2026-06-01 20:22:01.574
25857bf2-5aaa-4b75-8cc2-b9f53b2ba47a	+261342307565	Madagascar	+261	$2a$10$WBD3cDl5jKtCQaCdVaz4kuLMMIr6a5WbPj8Ym0dG2IqlKsG4FuPge	2026-06-01 20:27:44.128	0	2026-06-01 20:22:44.392	2026-06-01 20:22:44.13	2026-06-01 20:22:44.392
d5eb23ed-b717-4ec0-aa4b-b14c8d6ff4db	+261349459128	Madagascar	+261	$2a$10$wPx/spqOj2OCLU6pL24HF.yY4DmdUf8MNlRc5r3OycA8j1VzXRRQO	2026-06-01 20:42:27.358	0	2026-06-01 20:37:28.129	2026-06-01 20:37:27.359	2026-06-01 20:37:28.13
148647e3-595c-4657-91bd-7c2f0690c52a	+261342307565	Madagascar	+261	$2a$10$oDGIytO1JewcFPBZvP0sweFsmiGR8EnPP/8ePzdZ8cdx5zhr.tRoi	2026-06-01 20:42:34.93	0	2026-06-01 20:37:35.35	2026-06-01 20:37:34.931	2026-06-01 20:37:35.351
337403cf-9cf7-409c-a128-7e4351735477	+261342307565	Madagascar	+261	$2a$10$XdvmsjR511o0NCvI6xq.HenWoSExIt6IgnMxg1sMkmm10rshhQo5y	2026-06-09 19:15:41.282	0	2026-06-09 19:10:42.062	2026-06-09 19:10:41.286	2026-06-09 19:10:42.064
fabafc72-dc0a-473f-8596-ea2d13c8124c	+261349459128	Madagascar	+261	$2a$10$AIgWKjbVi2nlYDB1Ai79Q.o/VHygiKc0pxbs5GTxZO4LP/K/Dyx9W	2026-06-09 19:16:45.245	0	2026-06-09 19:11:45.876	2026-06-09 19:11:45.248	2026-06-09 19:11:45.877
fc126f9c-1bb6-4c75-831d-f53e45993d69	+261349459128	Madagascar	+261	$2a$10$4MgEk6goNQsD.4f0HBoJEOIsZxuHg/eI3TkP8NF.Nsdythkuyisce	2026-06-09 19:58:18.559	0	2026-06-09 19:53:19.162	2026-06-09 19:53:18.561	2026-06-09 19:53:19.163
38143f04-297f-4a02-b976-866f03ca4b3c	+261349459128	Madagascar	+261	$2a$10$9mHexJTdOiHTMy2OE.iSpuQABYth36x982FBkTsEd4JLCUO1tvgKS	2026-06-09 20:12:45.464	0	2026-06-09 20:07:45.883	2026-06-09 20:07:45.466	2026-06-09 20:07:45.885
932bbb01-cabb-4e61-92be-f0034eb19419	+261342307565	Madagascar	+261	$2a$10$8PBO6y6bPjfavw0bcuOU3e0rnFheyexCFPBwD6rFHODmTMDWriFPK	2026-06-09 20:13:12.615	0	2026-06-09 20:08:13.603	2026-06-09 20:08:12.617	2026-06-09 20:08:13.605
8384acdb-ad70-431d-9a49-eb207d04d85f	+261349459128	Madagascar	+261	$2a$10$WQCTHAgMq63tdjj0sjprx.dxMbZPihm1bQKdBBuF5RGZ44nZc3yVy	2026-08-04 18:52:33.017	0	2026-08-04 18:47:33.452	2026-08-04 18:47:33.019	2026-08-04 18:47:33.453
36f55d9c-2cfc-45a9-8b91-938eeac84e14	+261342307568	Madagascar	+261	$2a$10$IlN0tl/AfZHD8SeCbBPz8.wzWv/1uobeL.EWbAQ7am9cKGme/isJq	2026-08-04 18:56:52.951	0	2026-08-04 18:51:53.179	2026-08-04 18:51:52.952	2026-08-04 18:51:53.18
4f312877-3b7d-426e-9ae6-03cc957bd0f1	+261349459128	Madagascar	+261	$2a$10$rY8ydSLV01X4/s6RVMc70eenhF8uDUgOy9BkA6Hh2eRRF6G2JA8oa	2026-08-06 00:07:34.338	0	2026-08-06 00:02:34.829	2026-08-06 00:02:34.34	2026-08-06 00:02:34.831
21fb3322-b7ba-4cbe-8345-cf089372d82c	+261349459128	Madagascar	+261	$2a$10$lIiPk2tcTagjA/YaO0kZguE.TZXLfhMY8XT9r3hISWpHQhchoSmcO	2026-08-06 00:15:16.203	0	2026-08-06 00:10:16.517	2026-08-06 00:10:16.204	2026-08-06 00:10:16.518
9305e032-dd4b-4493-be74-9d941c3ef8a8	+261342307565	Madagascar	+261	$2a$10$p//pjvh70WgiMmgBs4qe4.T2ZKPY8yNJxoJ9QE6LDzCqmoK0UBCgK	2026-08-06 00:40:58.209	0	2026-08-06 00:35:59.787	2026-08-06 00:35:58.211	2026-08-06 00:35:59.79
\.


--
-- Data for Name: Product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Product" (id, title, description, "imageUrl", "priceAmount", "currencyCode", "isAvailable", "createdAt", "updatedAt", "sellerProfileId", "categoryId") FROM stdin;
c79d01a5-8872-4e86-b588-9e6c98b53bd2	gente moto	gente  moto routière	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775282364/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282360011?_a=BAMAOGfk0	145000.00	MGA	t	2026-04-04 05:59:25.037	2026-04-04 05:59:25.037	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2712b453-15f3-4e50-a095-e5716fccb144
3a4a58b8-8f96-42dd-b14f-f0ba045747e4	MOTO New Mada	moto soa be de soa be de tena soa be	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000.00	MGA	t	2026-04-04 16:36:41.496	2026-04-20 19:31:21.435	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2712b453-15f3-4e50-a095-e5716fccb144
7cd76f8d-41f4-45c9-b83b-6dc986840016	teszpfbe	je suis landescription	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784342/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784338965?_a=BAMAOGfk0	12000.00	MGA	t	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	cddc0066-1179-4a16-aa8a-7edeea79d0bc	0ff5279a-a20f-4094-a5e5-9cb3073d707d
30e26f74-1462-4829-bb70-beea516822f3	boucle d oreil	hdlskzgzhjzjz	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284309921?_a=BAMAOGfk0	10000.00	MGA	f	2026-04-04 06:31:58.454	2026-05-09 04:02:29.722	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2a64e44f-b82c-451a-95b7-2562177e6c6a
1d3d6860-131f-4c8e-aa45-737a0f27d81b	oppo renault 5 pro	best description	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636953?_a=BAMAOGfk0	460000.00	MGA	f	2026-04-04 06:37:21.627	2026-05-09 04:02:49.229	cddc0066-1179-4a16-aa8a-7edeea79d0bc	65e0a618-b863-4562-b1dd-319e3ef7a197
prod-seed-bag	Sac a main cuir premium	Mode feminine avec finition cuir elegante.	https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800	280000.00	MGA	t	2026-04-02 16:43:30.301	2026-05-13 19:24:19.061	508bbb87-c08e-411c-b550-d17e910b4cbb	f5df6305-1ab6-4f3b-9972-ebebc10053d5
prod-seed-chair	Chaise design minimaliste	Assise confortable pour salon ou bureau moderne.	https://images.unsplash.com/photo-1519947486511-46149fa0a254?w=800	145000.00	MGA	t	2026-04-02 16:43:30.301	2026-05-13 19:24:19.061	508bbb87-c08e-411c-b550-d17e910b4cbb	95c627c8-23ee-40eb-87b6-79d1d8256f8f
prod-seed-iphone	iPhone 13 Pro Max	Smartphone premium avec excellent appareil photo.	https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800	3150000.00	MGA	t	2026-04-02 16:43:30.301	2026-05-13 19:24:19.061	fca37388-adbd-44e3-b289-b98415b97eab	55dd2ced-64b4-4b70-8b06-7250b9fa2fe1
prod-seed-perfume	Coffret parfum prestige	Selection premium pour cadeaux et occasions speciales.	https://images.unsplash.com/photo-1541643600914-78b084683601?w=800	190000.00	MGA	t	2026-04-02 16:43:30.302	2026-05-13 19:24:19.061	6a138d49-94b3-4f80-9e9b-cf137bc0a245	e28856dc-ae47-4d6f-abfc-d394b19793fa
\.


--
-- Data for Name: ProductComment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductComment" (id, content, "createdAt", "updatedAt", "userId", "productId", "parentCommentId") FROM stdin;
1840bb98-fb67-432a-a189-cf3e2478a780	Mbola ato ve ito zafady	2026-04-19 14:35:44.706	2026-04-19 14:35:44.706	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
2f1c827e-8072-46a5-a5f3-28137a9ac71e	@DAMA Dany bisous	2026-04-19 14:36:05.677	2026-04-19 14:36:05.677	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	1840bb98-fb67-432a-a189-cf3e2478a780
bac757d1-a948-4927-b719-832f08c8a3a9	@Vony Verronique Merci bisous aussis	2026-04-19 14:36:38.225	2026-04-19 14:36:38.225	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	2f1c827e-8072-46a5-a5f3-28137a9ac71e
d521fdae-4027-4a0f-865d-68ec0e572998	@DAMA Dany je taime	2026-04-19 14:37:10.538	2026-04-19 14:37:10.538	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	bac757d1-a948-4927-b719-832f08c8a3a9
bbf90904-21ef-40cd-861e-5e6a9a9af726	ao ve?	2026-04-19 15:02:19.068	2026-04-19 15:02:19.068	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
dcd6b879-c8d2-4b02-ad31-3d49993c88b6	mbola dispo ve	2026-04-19 16:10:42.35	2026-04-19 16:10:42.35	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
d3339615-f403-48cd-bae9-9498586ba02a	any	2026-04-19 16:11:12.475	2026-04-19 16:11:12.475	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
9427f549-0a71-426a-a5c3-9724faa6f8d9	test	2026-04-19 16:12:13.501	2026-04-19 16:12:13.501	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
5a840e9c-fa8d-4972-984f-09d8b9e32a86	@Juliana test ty	2026-04-19 16:12:39.783	2026-04-19 16:12:39.783	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	d3339615-f403-48cd-bae9-9498586ba02a
56aec64e-b393-40e1-8d05-8b49cc7875f7	@Juliana mety ve	2026-04-19 16:13:34.841	2026-04-19 16:13:34.841	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	d3339615-f403-48cd-bae9-9498586ba02a
7296da76-b4aa-4a15-ae87-92ee129f351c	jdkzkz	2026-04-20 03:43:22.148	2026-04-20 03:43:22.148	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
fc7bc725-403e-4644-9119-0bdc988de0de	@Vony Verronique hiya	2026-04-20 03:43:54.797	2026-04-20 03:43:54.797	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	7296da76-b4aa-4a15-ae87-92ee129f351c
2ff0ed97-740e-424c-976a-dff7e1a2f52e	tyhhu	2026-04-20 03:44:01.281	2026-04-20 03:44:01.281	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
b803729c-673f-4c49-8026-32fe624b96a1	Soa ka	2026-04-20 19:33:03.87	2026-04-20 19:33:03.87	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	\N
76ff6dd3-d463-43fd-8254-bad5bbbb2e24	eeg	2026-05-19 08:22:22.995	2026-05-19 08:22:22.995	b718efee-173e-441b-98f3-364b40c05e73	7cd76f8d-41f4-45c9-b83b-6dc986840016	\N
15a24219-819b-4c3f-8562-553b831ceb94	@Vony Verronique ewa ewa	2026-05-29 19:54:57.89	2026-05-29 19:54:57.89	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	1840bb98-fb67-432a-a189-cf3e2478a780
\.


--
-- Data for Name: ProductCommentMention; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductCommentMention" (id, "createdAt", "commentId", "mentionedUserId") FROM stdin;
47ac958c-f5a9-4917-aa1a-647ad98e38b0	2026-04-19 14:36:05.677	2f1c827e-8072-46a5-a5f3-28137a9ac71e	fc758d78-e3c2-4ea7-a489-8e2886635f13
05a76eac-1f6b-406e-8160-bd21342205df	2026-04-19 14:36:38.225	bac757d1-a948-4927-b719-832f08c8a3a9	b718efee-173e-441b-98f3-364b40c05e73
f2fde139-a8b5-4ad3-8958-04449bdbe442	2026-04-19 14:37:10.538	d521fdae-4027-4a0f-865d-68ec0e572998	fc758d78-e3c2-4ea7-a489-8e2886635f13
de41f5c7-b6c6-4aed-8465-c7a2a1893f81	2026-04-19 16:12:39.783	5a840e9c-fa8d-4972-984f-09d8b9e32a86	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
32399677-10e6-4cb0-beed-87b7155cc030	2026-04-19 16:13:34.841	56aec64e-b393-40e1-8d05-8b49cc7875f7	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
9810ee07-f499-4d1c-a14f-261640e5717f	2026-04-20 03:43:54.797	fc7bc725-403e-4644-9119-0bdc988de0de	b718efee-173e-441b-98f3-364b40c05e73
928074d1-27e5-4584-81bc-8619c1c5b934	2026-05-29 19:54:57.89	15a24219-819b-4c3f-8562-553b831ceb94	b718efee-173e-441b-98f3-364b40c05e73
\.


--
-- Data for Name: ProductImage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductImage" (id, "imageUrl", "sortOrder", "createdAt", "updatedAt", "productId") FROM stdin;
760486c9-68ac-48e7-a5ec-f09c5d39d76b	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	0	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
052ee540-7aa8-46f5-aa19-f5de7ab7d6b0	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596344?_a=BAMAOGfk0	1	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
5ec7d179-387b-4bf7-8a67-da92fc50a68c	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596346?_a=BAMAOGfk0	2	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
42a63280-aa52-44e4-9bd1-cb5fd2ee28ed	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1776713474/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1776713460907?_a=BAMAOGfk0	3	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
50beee25-5b9a-43a4-bd7b-4a64e657d940	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284309921?_a=BAMAOGfk0	0	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
b40231c8-9cc7-4aac-8006-776fab806115	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284318/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310041?_a=BAMAOGfk0	1	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
8549109f-649c-4b45-b9e2-2256a8d12e8d	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284315/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310042?_a=BAMAOGfk0	2	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
f3964d40-2c0a-4daa-9c19-5064fbb7816a	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284318/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310043?_a=BAMAOGfk0	3	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
045abdbc-edde-4e5d-969d-8089852ffce3	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310044?_a=BAMAOGfk0	4	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
79d79057-80ad-4598-96e9-fc853c254378	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310045?_a=BAMAOGfk0	5	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
a65d4b41-54f6-4641-91d9-0c61b60b51f5	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284316/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310046?_a=BAMAOGfk0	6	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
24010cea-3e1c-4654-a28f-ee73396ca188	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284316/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310047?_a=BAMAOGfk0	7	2026-05-09 04:02:29.722	2026-05-09 04:02:29.722	30e26f74-1462-4829-bb70-beea516822f3
80f53414-646c-4e30-bc15-45f35de9046f	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784347/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784339033?_a=BAMAOGfk0	3	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
6a69aec6-7875-478c-b68c-4ecad64db7b2	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784344/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784339034?_a=BAMAOGfk0	4	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
69136465-56af-4835-824e-cef2e837283d	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784351/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784339034?_a=BAMAOGfk0	5	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
9f49aec6-4ea8-4117-9631-4bf898095ae0	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636953?_a=BAMAOGfk0	0	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
b1fbba32-064e-46b9-81af-89c499694c34	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636961?_a=BAMAOGfk0	1	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
20b6ea5f-1877-42d3-983d-4bd5017a549b	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636966?_a=BAMAOGfk0	2	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
dbb25cb4-d2aa-48a5-a776-ddf0192517fd	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636971?_a=BAMAOGfk0	3	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
09b72f77-a81d-49ed-9be8-be5ce27870f6	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636976?_a=BAMAOGfk0	4	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
468e842d-a968-4c9d-add5-63e5e2da2cd9	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636980?_a=BAMAOGfk0	5	2026-05-09 04:02:49.229	2026-05-09 04:02:49.229	1d3d6860-131f-4c8e-aa45-737a0f27d81b
9e15ccd7-5508-41f4-8fba-fc826cdc822f	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784342/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784338965?_a=BAMAOGfk0	0	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
7f2e4266-1ee2-42e7-9dd7-5d822813e0c1	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784345/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784339030?_a=BAMAOGfk0	1	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
88b16518-38b3-497e-8496-9f8f33302717	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1778784344/BANAY/products/cddc006611794a16aa8a7edeea79d0bc-product-1778784339032?_a=BAMAOGfk0	2	2026-05-14 18:45:51.816	2026-05-14 18:45:51.816	7cd76f8d-41f4-45c9-b83b-6dc986840016
\.


--
-- Data for Name: ProductLike; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductLike" (id, "createdAt", "userId", "productId") FROM stdin;
52ebac60-8a42-4b59-a8b8-dee8ca83dda6	2026-04-05 16:37:11.177	b718efee-173e-441b-98f3-364b40c05e73	c79d01a5-8872-4e86-b588-9e6c98b53bd2
18641624-d3ba-496a-9492-fac56928c3ab	2026-04-06 03:24:09.931	fc758d78-e3c2-4ea7-a489-8e2886635f13	c79d01a5-8872-4e86-b588-9e6c98b53bd2
a4933451-650d-4e9a-beb4-e01bbf01c0ee	2026-04-06 03:26:40.33	fc758d78-e3c2-4ea7-a489-8e2886635f13	1d3d6860-131f-4c8e-aa45-737a0f27d81b
ca7a8067-d16e-41ea-abe2-91977f0f7bff	2026-04-06 03:49:34.169	fc758d78-e3c2-4ea7-a489-8e2886635f13	30e26f74-1462-4829-bb70-beea516822f3
ab59298e-bf65-4935-9014-432ab18d6f27	2026-04-19 16:41:01.101	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
e809e750-97fb-4cdd-938d-89cfe0ee3be7	2026-04-19 16:41:11.666	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	1d3d6860-131f-4c8e-aa45-737a0f27d81b
06badb85-feac-4efe-a500-119731c644f7	2026-04-27 17:08:17.68	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
8b6e8c64-96b9-4a8c-b8f4-9bf9d4b51c7b	2026-06-01 17:03:56.734	b718efee-173e-441b-98f3-364b40c05e73	7cd76f8d-41f4-45c9-b83b-6dc986840016
8c3351ff-eb60-4430-ae81-0f4821c3e022	2026-08-06 00:49:32.333	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
\.


--
-- Data for Name: ProductShare; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductShare" (id, "createdAt", "userId", "productId") FROM stdin;
39676476-16cb-4869-9206-baa17ee72b7c	2026-04-05 13:56:22.399	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
7abee35c-ec95-4237-8abc-c5823c4fc310	2026-04-05 13:56:24.793	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
1eaa8050-7e0c-4359-890d-ff82d949c4e0	2026-04-06 13:34:05.31	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
daabf6b9-0191-49e1-a535-2f24ca574149	2026-04-06 15:47:40.169	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
a4ebad81-24ee-4636-97ba-1a8a371acbe5	2026-04-19 13:50:28.931	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
356755c0-074a-459f-939e-b01ffd62826c	2026-04-27 17:12:29.371	b718efee-173e-441b-98f3-364b40c05e73	1d3d6860-131f-4c8e-aa45-737a0f27d81b
1b8edc11-a15c-4e03-9fa4-1d2238687fab	2026-05-07 02:26:15.428	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
81adfcba-e4c7-4f7b-b9a2-8158174e0875	2026-05-19 08:22:54.65	b718efee-173e-441b-98f3-364b40c05e73	7cd76f8d-41f4-45c9-b83b-6dc986840016
08b7871a-d38e-42e4-b380-999ebd293f29	2026-05-19 08:22:58.749	b718efee-173e-441b-98f3-364b40c05e73	7cd76f8d-41f4-45c9-b83b-6dc986840016
a7d08e14-2aa9-4e7f-87c3-f1533ae99863	2026-05-19 15:57:18.938	b718efee-173e-441b-98f3-364b40c05e73	prod-seed-chair
237e3a57-751d-4198-9902-975ce08f8ae8	2026-05-19 16:08:13.233	b718efee-173e-441b-98f3-364b40c05e73	prod-seed-chair
2acf910b-bcfa-4968-9b42-e4c8a736a7c9	2026-05-19 16:08:32.194	b718efee-173e-441b-98f3-364b40c05e73	prod-seed-chair
\.


--
-- Data for Name: RefreshToken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."RefreshToken" (id, "tokenHash", "expiresAt", "createdAt", "userId") FROM stdin;
539e7737-986a-4d8c-8969-b79594c9e43b	$2a$10$qCrLcBrofcQSti82PNblBOYrNN6FphfFF65lfCr2Ku7YDCqoLwLf6	2026-04-09 16:46:26.437	2026-04-02 16:46:26.439	b59f5d68-ec21-44d1-adf3-33786f0d3a35
e9ac2183-6e6b-4585-86b2-3d2ae55883fa	$2a$10$xARoOcDKZ7ah34FoFV8GD.A8evrRERXbRNhgWOYYVA3/O.w0ojFMu	2026-09-05 01:53:10.013	2026-08-06 01:53:10.014	fc758d78-e3c2-4ea7-a489-8e2886635f13
3dac5f1c-665d-433b-9ff8-8b063fcd4c02	$2a$10$/vObzGnsJ7fzPBxguEfRJu.5IXhqvZwX.KKig3b6kvGkaAmWvpCv6	2026-05-03 04:42:25.807	2026-04-03 04:42:25.808	f261a10b-c29c-4bd3-a413-bf99ee82cdb0
a1343801-67ff-41bf-831a-44d40ffe5a56	$2a$10$EYghdZk6jX/D2p5RGVe1Mu/vF0SjbvNH9UEU9h2jaGnQQsNnJAxQO	2026-05-26 09:48:28.352	2026-04-26 09:48:28.354	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
02155aef-2fa3-4e3a-8fe0-310e6c49e2c8	$2a$10$piUaHJUuRPH2PMOzlwWze.krgz0qwLWBihwSycBji9kUn0.X0N2aK	2026-05-26 09:50:54.292	2026-04-26 09:50:54.293	9b3b238f-3e67-4073-9b6b-afbd3731f195
a93b5b8d-bf71-41c7-814e-ca094db6695d	$2a$10$83fmW11bDWIZxoRUGCf22u8U1j02to8Hx3Re.s7rNRiGy9ZqhpDpu	2026-09-05 01:52:13.566	2026-08-06 01:52:13.567	b718efee-173e-441b-98f3-364b40c05e73
72630853-f53f-4fec-a57d-1bf59c5120dd	$2a$10$K22ypw6k72ZF9UVHp6dFGucPB41AbdFy2mOGDu0h7h22k/64rRZ.e	2026-06-04 18:22:11.49	2026-05-05 18:22:11.492	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
30558cb1-2c07-47ad-87ae-251146bda88f	$2a$10$ZzFKWKxRx89WAbJE3OJsZ.nZT8wD6E/4lcY2v1bY89yydsqEsAeKa	2026-09-03 18:52:03.235	2026-08-04 18:52:03.236	533ed33f-dbe8-419a-8285-77dd01a553e7
\.


--
-- Data for Name: SearchHistory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SearchHistory" (id, "userId", query, "normalizedQuery", "resultCount", "occurrenceCount", "createdAt", "updatedAt", "lastSearchedAt") FROM stdin;
\.


--
-- Data for Name: SellerFollow; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SellerFollow" (id, "createdAt", "followerUserId", "sellerProfileId") FROM stdin;
d692aeed-65bd-4974-b400-6da32d87c227	2026-04-06 16:17:56.317	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
0c74cbbf-78e8-4974-9bfe-fc704fbdcace	2026-04-20 03:45:38.518	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	cddc0066-1179-4a16-aa8a-7edeea79d0bc
8251534e-e1e7-466d-b917-1c6b51d79c15	2026-04-26 09:51:26.065	9b3b238f-3e67-4073-9b6b-afbd3731f195	cddc0066-1179-4a16-aa8a-7edeea79d0bc
\.


--
-- Data for Name: SellerLiveSession; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SellerLiveSession" (id, "sellerProfileId", title, category, "startedAt", "updatedAt", "endedAt") FROM stdin;
8250dc0d-cb38-4717-971f-4526870901f0	cddc0066-1179-4a16-aa8a-7edeea79d0bc	Vony Verronique en direct	Presentation produit	2026-05-10 15:35:44.454	2026-05-10 15:36:05.327	2026-05-10 15:36:05.325
\.


--
-- Data for Name: SellerProfile; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SellerProfile" (id, "studioName", description, city, country, "createdAt", "updatedAt", "userId") FROM stdin;
cddc0066-1179-4a16-aa8a-7edeea79d0bc	Vony Veronique	Boutique BANAY active sur la plateforme.	Mountain View	Santa Clara County	2026-04-04 04:58:22.363	2026-05-09 15:41:45.368	b718efee-173e-441b-98f3-364b40c05e73
seller-profile-verify-demo	Seller Verify Demo Shop	Compte de test pour verification vendeur admin.	Antananarivo	Madagascar	2026-05-13 19:23:42.571	2026-05-13 19:24:18.965	user-seller-verify-demo
6a138d49-94b3-4f80-9e9b-cf137bc0a245	NalaK	Parfums, beaute et cadeaux premium.	Fianarantsoa	Madagascar	2026-04-02 16:43:30.136	2026-05-13 19:24:19.021	4af03bff-0bbc-46fd-8936-061181dbda80
508bbb87-c08e-411c-b550-d17e910b4cbb	Elanga Store	Mode et accessoires soigneusement selectionnes.	Toamasina	Madagascar	2026-04-02 16:43:30.135	2026-05-13 19:24:19.021	5beec21f-4030-41a6-b602-2c5228646d8d
fca37388-adbd-44e3-b289-b98415b97eab	Jojol Store	Boutique high-tech et smartphones premium.	Antananarivo	Madagascar	2026-04-02 16:43:30.135	2026-05-13 19:24:19.021	f299317e-35da-484f-a473-4a66c0adc02d
\.


--
-- Data for Name: SellerProfileView; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SellerProfileView" (id, "createdAt", "viewerUserId", "sellerProfileId") FROM stdin;
31cebfef-7fe9-4a04-83b7-d43c91d5bcaa	2026-04-05 12:00:37.945	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
25b059a2-72da-4a84-acbf-90e64a84f3de	2026-04-05 13:47:29.646	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
9583d154-8306-411b-b5b0-1aef7d1e8283	2026-04-05 13:47:46.722	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
03a818d0-f991-4345-9ac8-0f422b8db4ed	2026-04-05 13:52:12.767	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
8f4540a2-b6a1-4c15-886f-29b0400087a5	2026-04-06 13:25:05.704	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
62d3b4cb-ea8d-436d-917c-6d39a0103399	2026-04-06 13:30:15.819	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
391c05a9-1c34-45e9-bfe0-448ae09b47d7	2026-04-06 13:34:09.102	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
a86111d8-d862-4a4d-936d-e1b866d7c1f2	2026-04-06 13:39:22.921	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
fc61fd56-3169-41d1-baf9-28332efd0e9c	2026-04-06 13:39:54.764	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
1c782b9f-69a3-4042-90a5-7adac4a62778	2026-04-06 13:43:49.172	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
150bd0e2-7cc0-430f-abc2-e77a2c76a1a6	2026-04-06 13:55:50.988	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
b2598a41-18ad-4de3-8560-124c5326e79f	2026-04-06 14:17:16.655	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
966e8d99-7364-4e59-82f4-d91ff7ecb24f	2026-04-06 14:52:07.301	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
fd649d9d-36f0-4777-81b4-fc257b572db0	2026-04-06 15:48:20.421	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
4f72961a-05f5-44ea-bb03-23d7763d5811	2026-04-06 15:54:44.893	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
77b5499b-05cf-408b-9a87-3fcc28d64479	2026-04-06 15:58:43.134	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
860a92e5-290c-4039-a8e2-203e925d7bb9	2026-04-06 16:05:06.72	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
dad754fb-c5f1-4691-ac33-3ac88e8bc857	2026-04-06 16:11:36.258	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
65a6d1af-1904-4e2a-9480-34ddc99ad6d9	2026-04-06 16:17:34.985	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
d560f4b6-99bf-4647-a91c-a19ff317e1cf	2026-04-06 16:22:18.787	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
ee13e4ff-d63f-445a-853f-7a20de80690d	2026-04-08 02:19:31.999	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
ede2ff9c-9fcc-4fd2-ac49-3359af8500ee	2026-04-08 02:20:49.544	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
53d0b8c2-c61c-41a9-9c25-cb807b214723	2026-04-08 15:35:47.804	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
c937c0e7-f5bc-489e-9594-07c3f8222ba9	2026-04-08 15:36:18.624	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
3ce4f3a8-acb4-4d37-9bd9-3890da763190	2026-04-08 15:37:10.478	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
c427e6f4-48f1-4f89-a3df-0f90ec38519a	2026-04-13 15:42:18.308	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
2b528d88-191b-4c07-96aa-b84a94ec330c	2026-04-19 12:52:01.1	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
fd11cd6e-e74b-403d-9818-7cad57d9ba48	2026-04-19 13:06:16.246	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
646bb5eb-5b49-4bd6-8e42-c30ae94fac14	2026-04-19 13:07:42.943	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
cc34af7f-3950-4f3a-a596-c49aa585a4d3	2026-04-19 13:47:12.998	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
a7a40051-e932-4a3f-9ed5-c2b8858c5e2c	2026-04-19 16:18:33.302	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	cddc0066-1179-4a16-aa8a-7edeea79d0bc
b3b335cc-e491-418b-8089-a973ea5c3199	2026-04-19 16:19:25.017	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	cddc0066-1179-4a16-aa8a-7edeea79d0bc
4dd4bb31-7b1d-4998-886c-b01d99e34461	2026-04-26 09:51:16.278	9b3b238f-3e67-4073-9b6b-afbd3731f195	cddc0066-1179-4a16-aa8a-7edeea79d0bc
8661860e-7285-4f16-b739-cd60600e38c5	2026-05-06 16:37:21.18	9a6c8f8b-bd18-4b9e-972f-1179e18da727	cddc0066-1179-4a16-aa8a-7edeea79d0bc
33bac936-76f0-46f6-b95b-a1af9937e496	2026-05-07 02:26:18.525	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
1194a333-b664-4a38-8920-1d584b1ba763	2026-05-07 02:26:21.362	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
2798edf4-a1dc-4ab1-8a1f-5f58df299d9f	2026-05-19 15:24:41.521	b718efee-173e-441b-98f3-364b40c05e73	508bbb87-c08e-411c-b550-d17e910b4cbb
4531f522-68e7-4d00-9ad6-e05d568fd851	2026-05-19 15:33:10.998	b718efee-173e-441b-98f3-364b40c05e73	508bbb87-c08e-411c-b550-d17e910b4cbb
942d50c1-2444-4645-8105-075d5b8ed71a	2026-05-19 15:33:23.74	b718efee-173e-441b-98f3-364b40c05e73	508bbb87-c08e-411c-b550-d17e910b4cbb
3f33dc3c-2fe4-447b-ae06-fc50ee8ca25f	2026-05-19 15:33:31.271	b718efee-173e-441b-98f3-364b40c05e73	508bbb87-c08e-411c-b550-d17e910b4cbb
c9d3bf87-3c85-4fa8-b68f-08e9621d3493	2026-05-29 19:39:12.237	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
4f7b78f4-97d5-49dc-bf1c-344c394efeb1	2026-05-29 19:39:48.363	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
d4a3f5f9-a306-4273-bad9-8a3be7a9e05e	2026-05-29 20:01:47.867	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
11e3ff71-27a5-4981-ac7d-68bdd501671a	2026-05-29 21:02:40.812	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
76eb80b5-748a-4128-95a5-47372c1f1486	2026-05-30 15:36:38.787	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
ad872419-290b-4ded-aa0a-2e8aa23772d2	2026-06-01 17:07:11.711	b718efee-173e-441b-98f3-364b40c05e73	508bbb87-c08e-411c-b550-d17e910b4cbb
fa660cc6-e8ee-4aa7-9616-26ce16ba514e	2026-06-01 18:24:07.097	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
feaa1bad-6167-48a6-82dc-339ca9cb360e	2026-06-01 20:22:53.367	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
5a81c834-b8ec-4917-a694-df190c80b775	2026-08-04 18:57:47.871	533ed33f-dbe8-419a-8285-77dd01a553e7	cddc0066-1179-4a16-aa8a-7edeea79d0bc
ca23a66a-472f-4daa-b7db-6323b0bc5572	2026-08-06 00:14:14.441	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
588b8873-8617-4df2-a6cc-b9636be0f9ca	2026-08-06 00:20:36.207	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
21585d76-90d5-4169-abb0-8c6aab6af3b7	2026-08-06 01:07:36.843	fc758d78-e3c2-4ea7-a489-8e2886635f13	cddc0066-1179-4a16-aa8a-7edeea79d0bc
\.


--
-- Data for Name: Shipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Shipment" (id, "carrierName", "trackingNumber", "shipmentStatus", "shippedAt", "deliveredAt", "createdAt", "updatedAt", "orderId") FROM stdin;
b1d4ba14-dc63-4bce-973f-f586e25ab452	Bahibo Express	BHB-TRACK-001	DELIVERED	2026-04-01 10:00:00	2026-04-03 16:30:00	2026-04-02 16:43:30.355	2026-04-02 16:43:30.355	e9daebd9-2af7-45cf-ade7-e4dc5fa0d4a9
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."User" (id, "phoneE164", "displayName", "passwordHash", "avatarUrl", "preferredLanguage", role, "isVerified", "createdAt", "updatedAt", "countryDialCode", "countryName", "coverImageUrl", "locationLabel", "locationLatitude", "locationLongitude", "locationUpdatedAt", "shopRequestReviewedAt", "shopRequestStatus", "shopRequestSubmittedAt", "displayNameChangedAt", "isSellerCertified", "sellerVerificationRequestStatus", "sellerVerificationRequestedAt", "sellerVerificationReviewedAt", "lastSeenAt") FROM stdin;
f261a10b-c29c-4bd3-a413-bf99ee82cdb0	+261346484348	Verbose	$2a$10$EE0jsyZDrGmBDBcQ87bJsObedqyKHTjovgMQ/0KAvPCIr0M5BW0XW	\N	\N	CUSTOMER	t	2026-04-03 00:19:30.407	2026-04-03 00:19:30.407	+261	Madagascar	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
9b3b238f-3e67-4073-9b6b-afbd3731f195	+261340258202	Fifih	$2a$10$VpQoX0HdGkG0Nflczvffh.o/zm01JGPnL/VhrzDkdiGvZ3qfaxGsW	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1777197054/bahibo/profile-avatars/261340258202-avatar-1777197047033?_a=BAMAOGfk0	\N	CUSTOMER	t	2026-04-26 09:50:54.166	2026-04-26 09:54:41.722	+261	Madagascar	\N	Tananarive, Antananarivo Renivohitra	-18.9399558	47.5298438	2026-04-26 09:51:14.715	\N	NONE	\N	\N	f	NONE	\N	\N	2026-04-26 09:54:41.718
f299317e-35da-484f-a473-4a66c0adc02d	+261340000111	Jojol Store	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=18	\N	SELLER	t	2026-04-02 16:43:29.902	2026-05-13 19:24:18.976	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
5beec21f-4030-41a6-b602-2c5228646d8d	+261340000222	Elanga Store	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=52	\N	SELLER	t	2026-04-02 16:43:29.902	2026-05-13 19:24:18.976	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
4af03bff-0bbc-46fd-8936-061181dbda80	+261340000333	NalaK	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=47	\N	SELLER	t	2026-04-02 16:43:29.902	2026-05-13 19:24:18.976	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
b718efee-173e-441b-98f3-364b40c05e73	+261342307565	Vony Verronique	$2a$10$FVg4gDRhnWDHQSnK11l.Muh/p3co6KLEEhCS9GAee1a1fxkWmNome	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1780082140/BANAY/profile-avatars/261342307565-avatar-1780082136055?_a=BAMAOGfk0	\N	SELLER	t	2026-04-02 20:47:00.078	2026-08-06 00:50:39.658	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1780332497/BANAY/profile-covers/261342307565-cover-1780332494356?_a=BAMAOGfk0	Mountain View, Santa Clara County	37.4219983	-122.084	2026-06-09 19:13:25.693	2026-04-04 04:58:22.354	APPROVED	2026-04-03 17:58:20.854	\N	t	APPROVED	2026-04-06 15:45:33.235	2026-04-06 15:46:21.466	2026-08-06 00:50:39.657
fc758d78-e3c2-4ea7-a489-8e2886635f13	+261349459128	DAMA Dany	$2a$10$fKFR4W0i0bj5BvjKD70bfOdMKQkRJWMeaV3bygzo28vAf./vX9552	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1775204355/bahibo/profile-avatars/261349459128-avatar-1775204348725?_a=BAMAOGfk0	\N	ADMIN	t	2026-04-02 20:28:04.151	2026-08-06 01:08:23.201	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1775203723/bahibo/profile-covers/261349459128-cover-1775203712268?_a=BAMAOGfk0	Tananarive, Antananarivo Renivohitra	-18.9417075	47.5292781	2026-08-06 01:08:18.38	\N	NONE	\N	\N	f	NONE	\N	\N	2026-08-06 01:08:23.2
b59f5d68-ec21-44d1-adf3-33786f0d3a35	+261341234567	Client Demo	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=15	\N	CUSTOMER	t	2026-04-02 16:43:29.855	2026-05-13 19:24:18.967	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
user-admin-demo	+261340000999	Admin Demo	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=3	\N	ADMIN	t	2026-05-13 19:23:42.547	2026-05-13 19:24:18.949	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
user-shop-pending-demo	+261340000444	Shop Pending Demo	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=21	\N	CUSTOMER	t	2026-05-13 19:23:42.565	2026-05-13 19:24:18.958	\N	\N	\N	\N	\N	\N	\N	\N	PENDING	2026-05-10 08:00:00	\N	f	NONE	\N	\N	\N
user-seller-verify-demo	+261340000555	Seller Verify Demo	$2a$10$EFazgBBXqoLK.RmII8vUP.vGx9iT8fa8qnvJYgPoqgbFrEzu.r8MO	https://i.pravatar.cc/240?img=24	\N	SELLER	t	2026-05-13 19:23:42.568	2026-05-13 19:24:18.962	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	PENDING	2026-05-11 09:00:00	\N	\N
f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	+261324965862	Juliana	$2a$10$E9x7KUr.eA6D8z1CW9wGWOXLVggaxdFRQjWnqy9H2wARxUF1ypelW	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1776614810/bahibo/profile-avatars/261324965862-avatar-1776614807121?_a=BAMAOGfk0	\N	CUSTOMER	t	2026-04-19 16:06:11.822	2026-05-07 02:18:43.237	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1776614839/bahibo/profile-covers/261324965862-cover-1776614835768?_a=BAMAOGfk0	Tananarive, Antananarivo Renivohitra	-18.9419035	47.5293971	2026-05-07 02:18:09.377	\N	NONE	\N	\N	f	NONE	\N	\N	2026-05-07 02:18:43.235
533ed33f-dbe8-419a-8285-77dd01a553e7	+261342307568	Vony	$2a$10$H.ktDaUVbS.YUFtec.QhXu6MJn07xluBHYbxfMZhx7w6jxb.bOslu	\N	\N	CUSTOMER	t	2026-08-04 18:52:03.156	2026-08-04 18:58:34.083	+261	Madagascar	\N	Tananarive, Antananarivo Renivohitra	-18.9449857	47.5329128	2026-08-04 18:58:34.082	\N	NONE	\N	\N	f	NONE	\N	\N	2026-08-04 18:58:33.109
9a6c8f8b-bd18-4b9e-972f-1179e18da727	+261320365103	Adobe	$2a$10$jckBlZ2OampTakx99CNBeucqduoAMXbEN5ywjZsSegodg3yStHULC	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1778085424/BANAY/profile-avatars/261320365103-avatar-1778085420095?_a=BAMAOGfk0	\N	CUSTOMER	t	2026-05-06 16:37:05.22	2026-05-07 02:21:33.325	+261	Madagascar	\N	Antananarivo, Antananarivo Renivohitra	-18.9452834	47.5329128	2026-05-07 02:05:52.146	\N	NONE	\N	\N	f	NONE	\N	\N	2026-05-07 02:21:33.324
\.


--
-- Data for Name: UserBlock; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UserBlock" (id, "blockerUserId", "blockedUserId", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: UserDeviceToken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UserDeviceToken" (id, "userId", token, platform, "createdAt", "updatedAt", "lastSeenAt") FROM stdin;
716adc98-e6a1-4026-9b86-4f34b6531fd9	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	dhpfAwxqRqKeA_0Ir0Q9hL:APA91bE5XyVRShExhnDJN0QPBr3C7IVlc0whqtI815KfZxyLkIaLYQWIddU4ClrtfY1f8-7IRpMcMWfQY4OvfbJHHxKTG4_TDhFwouHyzVmhyLM7XHNgJk4	android	2026-04-07 15:13:13.9	2026-04-26 09:48:36.737	2026-04-26 09:48:36.734
acc4d6d8-369f-454b-9201-2e1fed7c6a4c	9b3b238f-3e67-4073-9b6b-afbd3731f195	dMwGGt4OSM-HhHGf8ZbzHx:APA91bGwlcZ3IQYj0hRpyxZl4jg_MxGu1PFzVsCHz4mU9JyfQtv7R8EI7zWehvwxbaiPuVhKGp-hNGG0jGEDl0VXXARprtn1pjQCfhPVJhnWN2tWAj0yYLE	android	2026-04-26 09:50:54.478	2026-04-26 09:50:54.478	2026-04-26 09:50:54.477
a4f1e050-75d3-4639-b4fe-358ac5a3b668	fc758d78-e3c2-4ea7-a489-8e2886635f13	cMYIwqxeQD-PnQ1KtDoua_:APA91bFDZ9e2wivNAiHdXXft2BfB-GeU9DOGvSYaCgFxKOHoNmZswTx1QczWQiBtXJx0xxVbO5yTNZZl7B2vbW_KEM2MM5aQXS-8GuYUcXR01GZrP4_WgVg	android	2026-04-24 05:02:47.012	2026-04-26 13:27:18.402	2026-04-26 13:27:18.401
08f63ae8-481e-450f-a48f-dd815e0cd924	b718efee-173e-441b-98f3-364b40c05e73	fLBWPP9NROe29AUjVO61kP:APA91bEXqeUDFAdW0bXXf4qr2TLOZ504BssxbJOxr_X0g66mVPdlE1Ztl9xPBLBp8goorylGW8rUZbqNuBMOFl9_Kwn1U5OXCv4JxTwgpOYDv--leyVsuus	android	2026-05-05 15:31:38.234	2026-05-05 15:31:38.234	2026-05-05 15:31:38.233
187d275a-3e94-4a05-a350-147c2f64098e	b718efee-173e-441b-98f3-364b40c05e73	f4ggeTlFQu61emOkLlx8tU:APA91bHK5C8EML0c9l4qDFBDJ7ZPoT8DYo3acjjujRZvEEjGEWLAlCVRuR_anh5OC-jz-t5CWwZIU4QXVKxyK6NfrfYRXo-A6uUI__edVfcCorw1CJj874s	android	2026-05-17 16:43:14.481	2026-05-18 01:10:02.019	2026-05-18 01:10:02.018
accde2e9-da54-4705-abc0-9a37d88300c1	b718efee-173e-441b-98f3-364b40c05e73	dDvjSUkQR-28mi5zS3fAxW:APA91bFsTb8jyMqfExSWzorsNA1GT-nuKe68DR1twRjr8KkbmFqAxFZIfbrBMxj00xQtMpNyCLgdENIYO53H50V_AAi52l9ZIQ_EUT9MBlgBYYPgp4hyaGo	android	2026-05-13 15:09:19.166	2026-05-17 13:54:30.925	2026-05-17 13:54:30.924
32d520b3-759c-45b8-8f8a-0e7fd610946e	fc758d78-e3c2-4ea7-a489-8e2886635f13	fXZsxKdxSAm8XEbrzig7Oz:APA91bF_7HStOJUKdSn1I2u73oGgsFP_GIBDNP8dEGHWVLoMuDngTNtIfdd_l4olQ_GIri5T1rj5mdH2DOEG7fNnu7QQFTZ_obnehc6P1v2P-q_6aLH-pHw	android	2026-05-05 16:39:43.715	2026-05-12 16:20:35.33	2026-05-12 16:20:35.329
8fbcf093-fa9a-447a-a1cb-5415e34c0740	b718efee-173e-441b-98f3-364b40c05e73	cNvMLtYzQoOOh12JeiQgzb:APA91bGhNDzvP2qbyH5Pfk387bluvfaPAizz4WlSOrxWXh-9MD9djzArA76pANW0e4MJ_qN5Phw8hAxn9Hojxgr3loCYzLjTr2u_7KqfT0-QMmVujA73fqc	android	2026-05-19 20:35:43.162	2026-05-19 20:35:43.162	2026-05-19 20:35:43.161
532adbf7-c1dd-429a-abf0-08785138addf	b718efee-173e-441b-98f3-364b40c05e73	fmksh8oaQX-oEfgKptiWvc:APA91bE4hP3OrFq6BNRNqynvu9n6ekNAyDE3H4i4K0kjxJXrPUjJxQRUPffmF2Ra8eROoZP_685Fjtlamjnea8keLeO0ZKC8RtKtIskqotYnj_65jCPvJ6s	android	2026-08-06 00:36:01.409	2026-08-06 00:50:47.003	2026-08-06 00:50:47.001
630114c9-dc01-4e55-8d8c-82989bc29a37	fc758d78-e3c2-4ea7-a489-8e2886635f13	cOhzEF_8RCGZJYvJq5lj6W:APA91bEwh4wJVWKcjTqkQ91N7pplz98-g34cUPktW01CdUigK_aENsPn_gwLzX_PfIj0w8pDe3B_2Aulv_xGvcpTRck7FcfPNX7pLOKO-JfvFeWaMf25UOg	android	2026-06-09 19:53:20.121	2026-08-06 01:08:11.344	2026-08-06 01:08:11.342
\.


--
-- Data for Name: UserFeedback; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UserFeedback" (id, "userId", message, "createdAt", "updatedAt") FROM stdin;
feedback-admin-demo-1	b59f5d68-ec21-44d1-adf3-33786f0d3a35	Bonjour admin, ceci est un commentaire de test pour la boite de notifications.	2026-05-13 19:24:18.972	2026-05-13 19:24:18.972
45d630dd-a4ca-4038-b2bb-6ff48064be5e	b718efee-173e-441b-98f3-364b40c05e73	QA_LOG_EXPORT\n{"exportedAt":"2026-06-01T18:19:02.240005","eventCount":7,"events":[{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:16:51.115334","parameters":{"tab_index":3,"tab_name":"account"}},{"name":"session_authenticated","source":"auth","status":"success","timestamp":"2026-06-01T18:16:39.353065","parameters":{"phone_e164":"+261342307565"}},{"name":"otp_verified","source":"analytics","status":"success","timestamp":"2026-06-01T18:16:39.332676","parameters":{}},{"name":"otp_requested","source":"analytics","status":"success","timestamp":"2026-06-01T18:16:37.298656","parameters":{}},{"name":"notification_opened","source":"notifications","status":"success","timestamp":"2026-06-01T18:16:11.774435","parameters":{"notification_type":"avatar"}},{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:16:10.223696","parameters":{"tab_index":0,"tab_name":"home"}},{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:15:40.932170","parameters":{"tab_index":3,"tab_name":"account"}}],"transport":"notifications_feedback","source":"qa_hidden_screen"}	2026-06-01 18:19:03.839	2026-06-01 18:19:03.839
8e6dfe37-8ed8-4053-87d6-6127410a6fd7	b718efee-173e-441b-98f3-364b40c05e73	QA_LOG_EXPORT\n{"exportedAt":"2026-06-01T18:19:21.338148","eventCount":7,"events":[{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:16:51.115334","parameters":{"tab_index":3,"tab_name":"account"}},{"name":"session_authenticated","source":"auth","status":"success","timestamp":"2026-06-01T18:16:39.353065","parameters":{"phone_e164":"+261342307565"}},{"name":"otp_verified","source":"analytics","status":"success","timestamp":"2026-06-01T18:16:39.332676","parameters":{}},{"name":"otp_requested","source":"analytics","status":"success","timestamp":"2026-06-01T18:16:37.298656","parameters":{}},{"name":"notification_opened","source":"notifications","status":"success","timestamp":"2026-06-01T18:16:11.774435","parameters":{"notification_type":"avatar"}},{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:16:10.223696","parameters":{"tab_index":0,"tab_name":"home"}},{"name":"navigation_tab_selected","source":"navigation","status":"success","timestamp":"2026-06-01T18:15:40.932170","parameters":{"tab_index":3,"tab_name":"account"}}],"transport":"notifications_feedback","source":"qa_hidden_screen"}	2026-06-01 18:19:22.954	2026-06-01 18:19:22.954
\.


--
-- Data for Name: UserReport; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."UserReport" (id, "reporterUserId", "reportedUserId", "conversationId", reason, details, "blockRequested", "createdAt") FROM stdin;
8c2be423-c90e-414e-aecd-c52841851ab3	b718efee-173e-441b-98f3-364b40c05e73	fc758d78-e3c2-4ea7-a489-8e2886635f13	6f944b8f-5750-4974-b8cb-a4c71f75ac07	CHAT_REPORT	\N	t	2026-04-13 17:10:19.623
e788bbcc-2910-4777-a355-56b7458c08b7	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	b718efee-173e-441b-98f3-364b40c05e73	58e36424-de24-4007-88f3-8da16709cf7a	CHAT_REPORT	\N	t	2026-04-19 16:21:46.724
b9ee9c08-acca-4cab-b388-745d2bc577d7	fc758d78-e3c2-4ea7-a489-8e2886635f13	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	eb4f3a52-78e6-4091-86ff-27067139f577	CHAT_REPORT	\N	t	2026-04-20 17:10:44.76
68240612-2a3f-4389-a192-9d0d5f2616f6	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	6f944b8f-5750-4974-b8cb-a4c71f75ac07	CHAT_REPORT	\N	t	2026-04-20 19:01:00.885
1cd38a1d-6a7b-467f-a56c-92d11d565111	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	6f944b8f-5750-4974-b8cb-a4c71f75ac07	CHAT_REPORT	\N	t	2026-04-20 19:06:11.191
36fb8393-6177-40a8-ac9b-896c6f0a7137	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	6f944b8f-5750-4974-b8cb-a4c71f75ac07	CHAT_REPORT	\N	t	2026-04-20 19:08:39.051
\.


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
5ebf8138-d542-40da-b177-ae55cc0a881d	cb931a5cb196ebe8c6ded2d890758e1b92781a49ebcd1c2f76387df3e8c73fcf	2026-05-13 21:41:16.180495+02	20260513_baseline		\N	2026-05-13 21:41:16.180495+02	0
0f49bb39-5c99-4fe7-814e-6f2ba4e2ba6a	2dcb2fad4a6f747a1250b830e5089b6bc4bc9f900c40276f2656f98d01b81f7e	2026-05-14 06:50:33.533238+02	20260514_add_user_feedback		\N	2026-05-14 06:50:33.533238+02	0
db12a082-3d91-40a4-be8e-8ce96078342d	b761e0027bf952efe630868b04fd877aacf52cdec3781e9f1feaea694e10862f	2026-05-14 09:26:32.032512+02	20260514_chat_schema_sync		\N	2026-05-14 09:26:32.032512+02	0
1f625943-bfc5-4fd3-8228-841e6333d74b	dc2228b32c6880b0f8fb6d554174b18869ce55febd2fbcdf937ceceffe73cffb	\N	20260516_message_delete_edit	A migration failed to apply. New migrations cannot be applied before the error is recovered from. Read more about how to resolve migration issues in a production database: https://pris.ly/d/migrate-resolve\n\nMigration name: 20260516_message_delete_edit\n\nDatabase error code: 42701\n\nDatabase error:\nERREUR: la colonne « deletedForSenderAt » de la relation « ChatMessage » existe déjà\n\nDbError { severity: "ERREUR", parsed_severity: Some(Error), code: SqlState(E42701), message: "la colonne « deletedForSenderAt » de la relation « ChatMessage » existe déjà", detail: None, hint: None, position: None, where_: None, schema: None, table: None, column: None, datatype: None, constraint: None, file: Some("tablecmds.c"), line: Some(7481), routine: Some("check_for_column_name_collision") }\n\n   0: sql_schema_connector::apply_migration::apply_script\n           with migration_name="20260516_message_delete_edit"\n             at schema-engine\\connectors\\sql-schema-connector\\src\\apply_migration.rs:113\n   1: schema_commands::commands::apply_migrations::Applying migration\n           with migration_name="20260516_message_delete_edit"\n             at schema-engine\\commands\\src\\commands\\apply_migrations.rs:95\n   2: schema_core::state::ApplyMigrations\n             at schema-engine\\core\\src\\state.rs:260	2026-06-01 22:56:42.424342+02	2026-06-01 22:56:22.370454+02	0
1d672408-c65e-459c-891e-90aeb958b531	dc2228b32c6880b0f8fb6d554174b18869ce55febd2fbcdf937ceceffe73cffb	2026-06-01 22:56:42.426347+02	20260516_message_delete_edit		\N	2026-06-01 22:56:42.426347+02	0
f1074cc1-0576-49aa-a8fd-83fb17e46637	a7695f2467d3960480910be9274894195d04ca4813d2763d960465ec32d46f0a	2026-06-01 22:56:44.751529+02	20260518_chat_delete_for_me_per_user	\N	\N	2026-06-01 22:56:44.744762+02	1
ac048c12-3230-4e54-b6ea-167e7cf2e15f	4219c02f62133748ccd822d826c774fae55b4d4d2036cf749ca21dee0178db6a	2026-06-01 22:56:44.769108+02	20260601_chat_message_receipts	\N	\N	2026-06-01 22:56:44.752277+02	1
\.


--
-- Name: CartItem CartItem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CartItem"
    ADD CONSTRAINT "CartItem_pkey" PRIMARY KEY (id);


--
-- Name: Cart Cart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Cart"
    ADD CONSTRAINT "Cart_pkey" PRIMARY KEY (id);


--
-- Name: Category Category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Category"
    ADD CONSTRAINT "Category_pkey" PRIMARY KEY (id);


--
-- Name: ChatConversation ChatConversation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatConversation"
    ADD CONSTRAINT "ChatConversation_pkey" PRIMARY KEY (id);


--
-- Name: ChatMessageMedia ChatMessageMedia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatMessageMedia"
    ADD CONSTRAINT "ChatMessageMedia_pkey" PRIMARY KEY (id);


--
-- Name: ChatMessage ChatMessage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatMessage"
    ADD CONSTRAINT "ChatMessage_pkey" PRIMARY KEY (id);


--
-- Name: NotificationReadState NotificationReadState_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationReadState"
    ADD CONSTRAINT "NotificationReadState_pkey" PRIMARY KEY (id);


--
-- Name: OrderItem OrderItem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_pkey" PRIMARY KEY (id);


--
-- Name: Order Order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Order"
    ADD CONSTRAINT "Order_pkey" PRIMARY KEY (id);


--
-- Name: PhoneOtpChallenge PhoneOtpChallenge_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."PhoneOtpChallenge"
    ADD CONSTRAINT "PhoneOtpChallenge_pkey" PRIMARY KEY (id);


--
-- Name: ProductCommentMention ProductCommentMention_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductCommentMention"
    ADD CONSTRAINT "ProductCommentMention_pkey" PRIMARY KEY (id);


--
-- Name: ProductComment ProductComment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductComment"
    ADD CONSTRAINT "ProductComment_pkey" PRIMARY KEY (id);


--
-- Name: ProductImage ProductImage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductImage"
    ADD CONSTRAINT "ProductImage_pkey" PRIMARY KEY (id);


--
-- Name: ProductLike ProductLike_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductLike"
    ADD CONSTRAINT "ProductLike_pkey" PRIMARY KEY (id);


--
-- Name: ProductShare ProductShare_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductShare"
    ADD CONSTRAINT "ProductShare_pkey" PRIMARY KEY (id);


--
-- Name: Product Product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Product"
    ADD CONSTRAINT "Product_pkey" PRIMARY KEY (id);


--
-- Name: RefreshToken RefreshToken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_pkey" PRIMARY KEY (id);


--
-- Name: SearchHistory SearchHistory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SearchHistory"
    ADD CONSTRAINT "SearchHistory_pkey" PRIMARY KEY (id);


--
-- Name: SellerFollow SellerFollow_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerFollow"
    ADD CONSTRAINT "SellerFollow_pkey" PRIMARY KEY (id);


--
-- Name: SellerLiveSession SellerLiveSession_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerLiveSession"
    ADD CONSTRAINT "SellerLiveSession_pkey" PRIMARY KEY (id);


--
-- Name: SellerProfileView SellerProfileView_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerProfileView"
    ADD CONSTRAINT "SellerProfileView_pkey" PRIMARY KEY (id);


--
-- Name: SellerProfile SellerProfile_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerProfile"
    ADD CONSTRAINT "SellerProfile_pkey" PRIMARY KEY (id);


--
-- Name: Shipment Shipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Shipment"
    ADD CONSTRAINT "Shipment_pkey" PRIMARY KEY (id);


--
-- Name: UserBlock UserBlock_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserBlock"
    ADD CONSTRAINT "UserBlock_pkey" PRIMARY KEY (id);


--
-- Name: UserDeviceToken UserDeviceToken_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserDeviceToken"
    ADD CONSTRAINT "UserDeviceToken_pkey" PRIMARY KEY (id);


--
-- Name: UserFeedback UserFeedback_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserFeedback"
    ADD CONSTRAINT "UserFeedback_pkey" PRIMARY KEY (id);


--
-- Name: UserReport UserReport_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserReport"
    ADD CONSTRAINT "UserReport_pkey" PRIMARY KEY (id);


--
-- Name: User User_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."User"
    ADD CONSTRAINT "User_pkey" PRIMARY KEY (id);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: CartItem_cartId_productId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "CartItem_cartId_productId_key" ON public."CartItem" USING btree ("cartId", "productId");


--
-- Name: Cart_userId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Cart_userId_key" ON public."Cart" USING btree ("userId");


--
-- Name: Category_slug_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Category_slug_key" ON public."Category" USING btree (slug);


--
-- Name: ChatConversation_buyerUserId_lastMessageAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatConversation_buyerUserId_lastMessageAt_idx" ON public."ChatConversation" USING btree ("buyerUserId", "lastMessageAt");


--
-- Name: ChatConversation_buyerUserId_sellerUserId_productId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ChatConversation_buyerUserId_sellerUserId_productId_key" ON public."ChatConversation" USING btree ("buyerUserId", "sellerUserId", "productId");


--
-- Name: ChatConversation_directKey_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ChatConversation_directKey_key" ON public."ChatConversation" USING btree ("directKey");


--
-- Name: ChatConversation_sellerUserId_lastMessageAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatConversation_sellerUserId_lastMessageAt_idx" ON public."ChatConversation" USING btree ("sellerUserId", "lastMessageAt");


--
-- Name: ChatMessageMedia_mediaGroupId_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessageMedia_mediaGroupId_idx" ON public."ChatMessageMedia" USING btree ("mediaGroupId");


--
-- Name: ChatMessageMedia_mediaType_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessageMedia_mediaType_createdAt_idx" ON public."ChatMessageMedia" USING btree ("mediaType", "createdAt");


--
-- Name: ChatMessageMedia_messageId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ChatMessageMedia_messageId_key" ON public."ChatMessageMedia" USING btree ("messageId");


--
-- Name: ChatMessage_conversationId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_conversationId_createdAt_idx" ON public."ChatMessage" USING btree ("conversationId", "createdAt");


--
-- Name: ChatMessage_conversationId_deliveredAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_conversationId_deliveredAt_idx" ON public."ChatMessage" USING btree ("conversationId", "deliveredAt");


--
-- Name: ChatMessage_conversationId_readAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_conversationId_readAt_idx" ON public."ChatMessage" USING btree ("conversationId", "readAt");


--
-- Name: ChatMessage_productId_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_productId_idx" ON public."ChatMessage" USING btree ("productId");


--
-- Name: ChatMessage_senderUserId_clientMessageId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ChatMessage_senderUserId_clientMessageId_key" ON public."ChatMessage" USING btree ("senderUserId", "clientMessageId");


--
-- Name: NotificationReadState_userId_notificationId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "NotificationReadState_userId_notificationId_key" ON public."NotificationReadState" USING btree ("userId", "notificationId");


--
-- Name: NotificationReadState_userId_readAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "NotificationReadState_userId_readAt_idx" ON public."NotificationReadState" USING btree ("userId", "readAt");


--
-- Name: Order_orderNumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Order_orderNumber_key" ON public."Order" USING btree ("orderNumber");


--
-- Name: PhoneOtpChallenge_phoneE164_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "PhoneOtpChallenge_phoneE164_createdAt_idx" ON public."PhoneOtpChallenge" USING btree ("phoneE164", "createdAt");


--
-- Name: ProductCommentMention_commentId_mentionedUserId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ProductCommentMention_commentId_mentionedUserId_key" ON public."ProductCommentMention" USING btree ("commentId", "mentionedUserId");


--
-- Name: ProductCommentMention_mentionedUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductCommentMention_mentionedUserId_createdAt_idx" ON public."ProductCommentMention" USING btree ("mentionedUserId", "createdAt");


--
-- Name: ProductComment_parentCommentId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductComment_parentCommentId_createdAt_idx" ON public."ProductComment" USING btree ("parentCommentId", "createdAt");


--
-- Name: ProductComment_productId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductComment_productId_createdAt_idx" ON public."ProductComment" USING btree ("productId", "createdAt");


--
-- Name: ProductComment_productId_parentCommentId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductComment_productId_parentCommentId_createdAt_idx" ON public."ProductComment" USING btree ("productId", "parentCommentId", "createdAt");


--
-- Name: ProductComment_userId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductComment_userId_createdAt_idx" ON public."ProductComment" USING btree ("userId", "createdAt");


--
-- Name: ProductImage_productId_sortOrder_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductImage_productId_sortOrder_idx" ON public."ProductImage" USING btree ("productId", "sortOrder");


--
-- Name: ProductLike_productId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductLike_productId_createdAt_idx" ON public."ProductLike" USING btree ("productId", "createdAt");


--
-- Name: ProductLike_userId_productId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "ProductLike_userId_productId_key" ON public."ProductLike" USING btree ("userId", "productId");


--
-- Name: ProductShare_productId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductShare_productId_createdAt_idx" ON public."ProductShare" USING btree ("productId", "createdAt");


--
-- Name: ProductShare_userId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ProductShare_userId_createdAt_idx" ON public."ProductShare" USING btree ("userId", "createdAt");


--
-- Name: SearchHistory_userId_normalizedQuery_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "SearchHistory_userId_normalizedQuery_key" ON public."SearchHistory" USING btree ("userId", "normalizedQuery");


--
-- Name: SearchHistory_userId_resultCount_lastSearchedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SearchHistory_userId_resultCount_lastSearchedAt_idx" ON public."SearchHistory" USING btree ("userId", "resultCount", "lastSearchedAt");


--
-- Name: SellerFollow_followerUserId_sellerProfileId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "SellerFollow_followerUserId_sellerProfileId_key" ON public."SellerFollow" USING btree ("followerUserId", "sellerProfileId");


--
-- Name: SellerFollow_sellerProfileId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SellerFollow_sellerProfileId_createdAt_idx" ON public."SellerFollow" USING btree ("sellerProfileId", "createdAt");


--
-- Name: SellerLiveSession_endedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SellerLiveSession_endedAt_idx" ON public."SellerLiveSession" USING btree ("endedAt");


--
-- Name: SellerLiveSession_sellerProfileId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "SellerLiveSession_sellerProfileId_key" ON public."SellerLiveSession" USING btree ("sellerProfileId");


--
-- Name: SellerLiveSession_startedAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SellerLiveSession_startedAt_idx" ON public."SellerLiveSession" USING btree ("startedAt");


--
-- Name: SellerProfileView_sellerProfileId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SellerProfileView_sellerProfileId_createdAt_idx" ON public."SellerProfileView" USING btree ("sellerProfileId", "createdAt");


--
-- Name: SellerProfileView_viewerUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "SellerProfileView_viewerUserId_createdAt_idx" ON public."SellerProfileView" USING btree ("viewerUserId", "createdAt");


--
-- Name: SellerProfile_userId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "SellerProfile_userId_key" ON public."SellerProfile" USING btree ("userId");


--
-- Name: Shipment_orderId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Shipment_orderId_key" ON public."Shipment" USING btree ("orderId");


--
-- Name: Shipment_trackingNumber_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "Shipment_trackingNumber_key" ON public."Shipment" USING btree ("trackingNumber");


--
-- Name: UserBlock_blockedUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserBlock_blockedUserId_createdAt_idx" ON public."UserBlock" USING btree ("blockedUserId", "createdAt");


--
-- Name: UserBlock_blockerUserId_blockedUserId_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "UserBlock_blockerUserId_blockedUserId_key" ON public."UserBlock" USING btree ("blockerUserId", "blockedUserId");


--
-- Name: UserBlock_blockerUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserBlock_blockerUserId_createdAt_idx" ON public."UserBlock" USING btree ("blockerUserId", "createdAt");


--
-- Name: UserDeviceToken_token_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "UserDeviceToken_token_key" ON public."UserDeviceToken" USING btree (token);


--
-- Name: UserDeviceToken_userId_lastSeenAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserDeviceToken_userId_lastSeenAt_idx" ON public."UserDeviceToken" USING btree ("userId", "lastSeenAt");


--
-- Name: UserFeedback_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserFeedback_createdAt_idx" ON public."UserFeedback" USING btree ("createdAt");


--
-- Name: UserFeedback_userId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserFeedback_userId_createdAt_idx" ON public."UserFeedback" USING btree ("userId", "createdAt");


--
-- Name: UserReport_conversationId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserReport_conversationId_createdAt_idx" ON public."UserReport" USING btree ("conversationId", "createdAt");


--
-- Name: UserReport_reportedUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserReport_reportedUserId_createdAt_idx" ON public."UserReport" USING btree ("reportedUserId", "createdAt");


--
-- Name: UserReport_reporterUserId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "UserReport_reporterUserId_createdAt_idx" ON public."UserReport" USING btree ("reporterUserId", "createdAt");


--
-- Name: User_phoneE164_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "User_phoneE164_key" ON public."User" USING btree ("phoneE164");


--
-- Name: CartItem CartItem_cartId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CartItem"
    ADD CONSTRAINT "CartItem_cartId_fkey" FOREIGN KEY ("cartId") REFERENCES public."Cart"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: CartItem CartItem_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."CartItem"
    ADD CONSTRAINT "CartItem_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Cart Cart_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Cart"
    ADD CONSTRAINT "Cart_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatConversation ChatConversation_buyerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatConversation"
    ADD CONSTRAINT "ChatConversation_buyerUserId_fkey" FOREIGN KEY ("buyerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatConversation ChatConversation_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatConversation"
    ADD CONSTRAINT "ChatConversation_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatConversation ChatConversation_sellerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatConversation"
    ADD CONSTRAINT "ChatConversation_sellerUserId_fkey" FOREIGN KEY ("sellerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatMessageMedia ChatMessageMedia_messageId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatMessageMedia"
    ADD CONSTRAINT "ChatMessageMedia_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES public."ChatMessage"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatMessage ChatMessage_conversationId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatMessage"
    ADD CONSTRAINT "ChatMessage_conversationId_fkey" FOREIGN KEY ("conversationId") REFERENCES public."ChatConversation"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ChatMessage ChatMessage_senderUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ChatMessage"
    ADD CONSTRAINT "ChatMessage_senderUserId_fkey" FOREIGN KEY ("senderUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: NotificationReadState NotificationReadState_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NotificationReadState"
    ADD CONSTRAINT "NotificationReadState_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OrderItem OrderItem_orderId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES public."Order"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: OrderItem OrderItem_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."OrderItem"
    ADD CONSTRAINT "OrderItem_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Order Order_buyerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Order"
    ADD CONSTRAINT "Order_buyerUserId_fkey" FOREIGN KEY ("buyerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Order Order_sellerProfileId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Order"
    ADD CONSTRAINT "Order_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES public."SellerProfile"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: ProductCommentMention ProductCommentMention_commentId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductCommentMention"
    ADD CONSTRAINT "ProductCommentMention_commentId_fkey" FOREIGN KEY ("commentId") REFERENCES public."ProductComment"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductCommentMention ProductCommentMention_mentionedUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductCommentMention"
    ADD CONSTRAINT "ProductCommentMention_mentionedUserId_fkey" FOREIGN KEY ("mentionedUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductComment ProductComment_parentCommentId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductComment"
    ADD CONSTRAINT "ProductComment_parentCommentId_fkey" FOREIGN KEY ("parentCommentId") REFERENCES public."ProductComment"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductComment ProductComment_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductComment"
    ADD CONSTRAINT "ProductComment_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductComment ProductComment_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductComment"
    ADD CONSTRAINT "ProductComment_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductImage ProductImage_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductImage"
    ADD CONSTRAINT "ProductImage_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductLike ProductLike_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductLike"
    ADD CONSTRAINT "ProductLike_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductLike ProductLike_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductLike"
    ADD CONSTRAINT "ProductLike_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductShare ProductShare_productId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductShare"
    ADD CONSTRAINT "ProductShare_productId_fkey" FOREIGN KEY ("productId") REFERENCES public."Product"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ProductShare ProductShare_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."ProductShare"
    ADD CONSTRAINT "ProductShare_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Product Product_categoryId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Product"
    ADD CONSTRAINT "Product_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES public."Category"(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: Product Product_sellerProfileId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Product"
    ADD CONSTRAINT "Product_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES public."SellerProfile"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: RefreshToken RefreshToken_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RefreshToken"
    ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SearchHistory SearchHistory_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SearchHistory"
    ADD CONSTRAINT "SearchHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SellerFollow SellerFollow_followerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerFollow"
    ADD CONSTRAINT "SellerFollow_followerUserId_fkey" FOREIGN KEY ("followerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SellerFollow SellerFollow_sellerProfileId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerFollow"
    ADD CONSTRAINT "SellerFollow_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES public."SellerProfile"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SellerLiveSession SellerLiveSession_sellerProfileId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerLiveSession"
    ADD CONSTRAINT "SellerLiveSession_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES public."SellerProfile"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SellerProfileView SellerProfileView_sellerProfileId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerProfileView"
    ADD CONSTRAINT "SellerProfileView_sellerProfileId_fkey" FOREIGN KEY ("sellerProfileId") REFERENCES public."SellerProfile"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SellerProfileView SellerProfileView_viewerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerProfileView"
    ADD CONSTRAINT "SellerProfileView_viewerUserId_fkey" FOREIGN KEY ("viewerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: SellerProfile SellerProfile_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."SellerProfile"
    ADD CONSTRAINT "SellerProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: Shipment Shipment_orderId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Shipment"
    ADD CONSTRAINT "Shipment_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES public."Order"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserBlock UserBlock_blockedUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserBlock"
    ADD CONSTRAINT "UserBlock_blockedUserId_fkey" FOREIGN KEY ("blockedUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserBlock UserBlock_blockerUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserBlock"
    ADD CONSTRAINT "UserBlock_blockerUserId_fkey" FOREIGN KEY ("blockerUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserDeviceToken UserDeviceToken_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserDeviceToken"
    ADD CONSTRAINT "UserDeviceToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserFeedback UserFeedback_userId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserFeedback"
    ADD CONSTRAINT "UserFeedback_userId_fkey" FOREIGN KEY ("userId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserReport UserReport_reportedUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserReport"
    ADD CONSTRAINT "UserReport_reportedUserId_fkey" FOREIGN KEY ("reportedUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: UserReport UserReport_reporterUserId_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."UserReport"
    ADD CONSTRAINT "UserReport_reporterUserId_fkey" FOREIGN KEY ("reporterUserId") REFERENCES public."User"(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 6w19AYU9GKE2sYW9NARYlbuDzYnxQeMnPOjLUAUBOxQhySMFyxNgyOGIYd7y1gT

