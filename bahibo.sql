--
-- PostgreSQL database dump
--

\restrict dsOUp8dCNFUP4yA5gzc2vGyzw2jR7nDGDHYal1QAMob6QZTMwtVCZRO4If9XvRc

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
    "replyToSenderUserId" text
);


ALTER TABLE public."ChatMessage" OWNER TO postgres;

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
\.


--
-- Data for Name: CartItem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."CartItem" (id, quantity, "createdAt", "updatedAt", "cartId", "productId") FROM stdin;
45507893-1154-47c8-9fe1-6aa82a260cb4	1	2026-04-02 16:43:30.334	2026-04-02 16:43:30.334	391154b5-38b6-4d84-86a2-a66a1c6ff7ef	prod-seed-bag
\.


--
-- Data for Name: Category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Category" (id, name, slug, icon, "createdAt", "updatedAt") FROM stdin;
55dd2ced-64b4-4b70-8b06-7250b9fa2fe1	Smartphones	smartphones	📱	2026-04-02 16:43:30.159	2026-04-02 16:43:30.159
e28856dc-ae47-4d6f-abfc-d394b19793fa	Beaute	beauty	🌸	2026-04-02 16:43:30.159	2026-04-02 16:43:30.159
f5df6305-1ab6-4f3b-9972-ebebc10053d5	Mode	fashion	👜	2026-04-02 16:43:30.159	2026-04-02 16:43:30.159
95c627c8-23ee-40eb-87b6-79d1d8256f8f	Maison	home	🪑	2026-04-02 16:43:30.159	2026-04-02 16:43:30.159
2712b453-15f3-4e50-a095-e5716fccb144	Moto	moto	\N	2026-04-04 05:59:20.009	2026-04-04 05:59:20.009
65e0a618-b863-4562-b1dd-319e3ef7a197	telephone	telephone	\N	2026-04-04 06:09:35.898	2026-04-04 06:09:35.898
2a64e44f-b82c-451a-95b7-2562177e6c6a	femme	femme	\N	2026-04-04 06:31:49.916	2026-04-04 06:31:49.916
710a07fa-b0cc-4994-b744-45584f9c6a50	uggucic	uggucic	\N	2026-04-04 16:36:36.218	2026-04-04 16:36:36.218
\.


--
-- Data for Name: ChatConversation; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChatConversation" (id, "buyerUserId", "sellerUserId", "productId", "createdAt", "updatedAt", "lastMessageAt", "directKey", kind) FROM stdin;
0c9fb139-6a31-40ff-bdf5-b541d3c010ec	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	fc758d78-e3c2-4ea7-a489-8e2886635f13	\N	2026-04-03 00:19:52.371	2026-04-03 04:43:51.817	2026-04-03 04:43:51.815	f261a10b-c29c-4bd3-a413-bf99ee82cdb0:fc758d78-e3c2-4ea7-a489-8e2886635f13	DIRECT
a980a82e-7a36-407b-ad1f-7cca92e60894	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	b718efee-173e-441b-98f3-364b40c05e73	\N	2026-04-03 04:44:21.892	2026-04-03 04:44:51.084	2026-04-03 04:44:51.083	b718efee-173e-441b-98f3-364b40c05e73:f261a10b-c29c-4bd3-a413-bf99ee82cdb0	DIRECT
eb4f3a52-78e6-4091-86ff-27067139f577	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	fc758d78-e3c2-4ea7-a489-8e2886635f13	\N	2026-04-19 16:20:24.512	2026-04-19 16:20:29.481	2026-04-19 16:20:29.479	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d:fc758d78-e3c2-4ea7-a489-8e2886635f13	DIRECT
58e36424-de24-4007-88f3-8da16709cf7a	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	b718efee-173e-441b-98f3-364b40c05e73	\N	2026-04-19 16:13:57.646	2026-04-19 16:38:59.378	2026-04-19 16:38:59.376	b718efee-173e-441b-98f3-364b40c05e73:f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	DIRECT
89da74d8-5b34-4b39-b0b6-c2271c3c03b5	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	30e26f74-1462-4829-bb70-beea516822f3	2026-04-05 12:02:19.708	2026-04-05 12:02:19.882	2026-04-05 12:02:19.88	\N	PRODUCT
9d9f9e58-60ce-46d5-b43e-6eb71afbc33a	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	c79d01a5-8872-4e86-b588-9e6c98b53bd2	2026-04-05 13:43:57.798	2026-04-05 13:44:37.021	2026-04-05 13:44:37.02	\N	PRODUCT
bb05bd3a-677a-4a81-abdf-61f81f3ba09b	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	4bae1fb8-7119-4588-a44c-7c98cd77fb2e	2026-04-05 16:22:01.021	2026-04-05 16:22:14.036	2026-04-05 16:22:14.035	\N	PRODUCT
ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	2026-04-05 12:01:37.104	2026-04-06 13:44:02.514	2026-04-06 13:44:02.512	\N	PRODUCT
aaceea95-27ca-4eff-a37c-246107bc51aa	9b3b238f-3e67-4073-9b6b-afbd3731f195	b718efee-173e-441b-98f3-364b40c05e73	\N	2026-04-26 09:52:05.637	2026-04-26 09:52:20.294	2026-04-26 09:52:20.292	9b3b238f-3e67-4073-9b6b-afbd3731f195:b718efee-173e-441b-98f3-364b40c05e73	DIRECT
6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	fc758d78-e3c2-4ea7-a489-8e2886635f13	\N	2026-04-02 21:46:37.594	2026-04-27 17:14:44.34	2026-04-27 17:14:44.339	b718efee-173e-441b-98f3-364b40c05e73:fc758d78-e3c2-4ea7-a489-8e2886635f13	DIRECT
\.


--
-- Data for Name: ChatMessage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ChatMessage" (id, "conversationId", "senderUserId", content, "createdAt", "readAt", "productId", "productImageUrl", "productPriceLabel", "productSubtitle", "productTitle", "replyToContent", "replyToMessageId", "replyToSenderName", "replyToSenderUserId") FROM stdin;
f570c086-2c56-4d6f-adc4-ff4e0190af6f	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	djeue	2026-04-02 21:49:41.969	2026-04-02 21:59:25.046	\N	\N	\N	\N	\N	\N	\N	\N	\N
2b7d3b02-5976-4e3c-beeb-c18400582f16	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	dfoisf	2026-04-02 21:46:41.178	2026-04-02 21:59:51.729	\N	\N	\N	\N	\N	\N	\N	\N	\N
292974c8-ac7f-4546-90e0-3b848f8151ea	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	sdoijfoisdjfoijdsfojsdf	2026-04-02 21:49:57.306	2026-04-02 21:59:51.729	\N	\N	\N	\N	\N	\N	\N	\N	\N
b11816c5-a452-4e31-9917-3e3320a519aa	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	je taime	2026-04-02 21:52:22.982	2026-04-02 21:59:51.729	\N	\N	\N	\N	\N	\N	\N	\N	\N
c1ec1c13-8f4d-4726-bc38-557c0fe3e266	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	Tsy mamaly	2026-04-02 21:59:45.396	2026-04-02 21:59:51.729	\N	\N	\N	\N	\N	\N	\N	\N	\N
b84bf62c-2e17-46d6-b3a1-41fdc2f80da6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	Ato ve	2026-04-02 22:00:12.865	2026-04-02 22:00:22.127	\N	\N	\N	\N	\N	\N	\N	\N	\N
ed7844d3-54d3-4e0c-be51-4125fcc22bdf	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ie	2026-04-02 22:00:26.499	2026-04-02 22:00:28.7	\N	\N	\N	\N	\N	\N	\N	\N	\N
dcc50d01-56bd-44c9-a3ca-6db0036aaf95	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	de aona	2026-04-02 22:00:46.305	2026-04-02 22:00:46.706	\N	\N	\N	\N	\N	\N	\N	\N	\N
ca89ab64-a76b-4f3e-8913-8b35545208c1	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	zao hiany manao inona ianao zao ?, Nga mbola tsy matory	2026-04-02 22:01:08.311	2026-04-02 22:01:10.095	\N	\N	\N	\N	\N	\N	\N	\N	\N
3ab563c8-46e1-4d8c-b905-a360fdf880ec	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	aiza	2026-04-02 22:32:35.096	2026-04-02 22:35:26.156	\N	\N	\N	\N	\N	\N	\N	\N	\N
d0a68c8f-08fc-449b-84ea-e221f457e481	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ao ve	2026-04-02 22:32:44.245	2026-04-02 22:35:26.156	\N	\N	\N	\N	\N	\N	\N	\N	\N
52ad094e-0f3f-46ab-bc92-cae9ce5c240e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	eooo	2026-04-02 22:35:09.043	2026-04-02 22:35:26.156	\N	\N	\N	\N	\N	\N	\N	\N	\N
8cbdd11e-c556-4e5d-b6de-6aca62d6d0b9	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ao ve	2026-04-02 22:35:21.193	2026-04-02 22:35:26.156	\N	\N	\N	\N	\N	\N	\N	\N	\N
ead07dfc-f372-424e-8980-e5905b960b53	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	fa misy inona	2026-04-02 22:35:30.701	2026-04-02 22:35:31.516	\N	\N	\N	\N	\N	\N	\N	\N	\N
64eb022c-f83d-4332-9f81-edf05e4dad68	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	efa alina zao	2026-04-02 22:35:41.004	2026-04-02 22:35:43.536	\N	\N	\N	\N	\N	\N	\N	\N	\N
da192876-16cc-498e-bfb5-6701f018bcf0	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ka zaho manao test envoie sms	2026-04-02 22:35:54.604	2026-04-02 22:35:55.536	\N	\N	\N	\N	\N	\N	\N	\N	\N
f242595c-2e81-4e07-8692-b4eaa7360dff	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	😃	2026-04-02 22:36:08.397	2026-04-02 22:36:10.537	\N	\N	\N	\N	\N	\N	\N	\N	\N
6f3820df-e4a7-4d33-abd1-189c8a14628c	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	mety ve	2026-04-02 22:39:40.904	2026-04-02 22:39:41.107	\N	\N	\N	\N	\N	\N	\N	\N	\N
6dd2ddf0-2c47-41f3-8476-3dbcaef68d06	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	mbola manao buid.debug	2026-04-02 22:39:54.732	2026-04-02 22:39:55.515	\N	\N	\N	\N	\N	\N	\N	\N	\N
41c262f1-247b-46ec-b89d-935f7165633e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	salut	2026-04-02 23:15:41.394	2026-04-02 23:16:29.774	\N	\N	\N	\N	\N	\N	\N	\N	\N
0e55556a-d647-432a-a43f-6cb690ccb3e6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	notif	2026-04-02 23:16:00.301	2026-04-02 23:16:29.774	\N	\N	\N	\N	\N	\N	\N	\N	\N
f71d06d7-0c84-42d9-85ea-9aeaeca2c24d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	not	2026-04-02 23:16:33.504	2026-04-02 23:16:42.516	\N	\N	\N	\N	\N	\N	\N	\N	\N
f5cad9a8-d2dd-4df2-b3cf-a0d76fb01131	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ter	2026-04-02 23:24:53.42	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
a67fb438-343c-4477-b7a6-c906a2392eaa	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	mety ve alou e?	2026-04-02 23:25:09.558	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
b1013256-c7cd-44c1-b0d2-15faf646b94d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	test am zay	2026-04-02 23:28:47.102	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
072b0d8a-2c7d-4513-bbcd-fc0e12426cc9	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	aya	2026-04-02 23:29:00.787	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
185a25e3-3038-45c5-a3da-32cfcfc25a28	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	eoo	2026-04-02 23:29:45.045	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
ee84b2f8-544c-4e9a-bd60-f158e4d5f911	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	kkk	2026-04-02 23:29:53.683	2026-04-02 23:30:34.512	\N	\N	\N	\N	\N	\N	\N	\N	\N
ed06fe73-0301-4578-82ff-50de6f2b6a7a	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	eo	2026-04-02 23:33:11.862	2026-04-02 23:37:57.2	\N	\N	\N	\N	\N	\N	\N	\N	\N
868366da-523f-4df5-9da4-fadcd2ee8498	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ggg	2026-04-02 23:33:20.182	2026-04-02 23:37:57.2	\N	\N	\N	\N	\N	\N	\N	\N	\N
ebfac953-f50c-4df2-b8f3-d69b59be2046	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oguffuvititvtvutviytc-tv-vr(rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr-(irb--bti	2026-04-02 23:33:52.884	2026-04-02 23:37:57.2	\N	\N	\N	\N	\N	\N	\N	\N	\N
bceaa4d3-24e2-467e-9f1f-1092f07577e2	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	pret	2026-04-02 23:37:49.757	2026-04-02 23:37:57.2	\N	\N	\N	\N	\N	\N	\N	\N	\N
84e6b20c-2300-4d0e-80f7-5f3ca7489fd4	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ok	2026-04-02 23:38:17.715	2026-04-02 23:38:18.22	\N	\N	\N	\N	\N	\N	\N	\N	\N
52133c43-0c37-45c8-a38d-e617b7f606e7	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ca mache	2026-04-02 23:38:34.889	2026-04-02 23:38:37.515	\N	\N	\N	\N	\N	\N	\N	\N	\N
389f3c86-8835-42f6-99c1-33442c5ab45e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hiiu	2026-04-02 23:38:58.295	2026-04-02 23:39:03.754	\N	\N	\N	\N	\N	\N	\N	\N	\N
308e575f-7766-4f01-93bc-dea041167bee	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	iguo	2026-04-02 23:43:04.838	2026-04-02 23:43:06.246	\N	\N	\N	\N	\N	\N	\N	\N	\N
1ce4ce23-c929-4976-ad09-a479465a89da	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ighui9uyy	2026-04-02 23:43:12.157	2026-04-02 23:43:12.258	\N	\N	\N	\N	\N	\N	\N	\N	\N
48568771-6191-4b14-a9ce-bd1ed6a5a19a	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	gdstuu	2026-04-02 23:43:15.723	2026-04-02 23:43:18.216	\N	\N	\N	\N	\N	\N	\N	\N	\N
024563d8-b64e-459b-aba9-9d2f8f57fec6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	i7fl7fl7fl7dl7fo7	2026-04-02 23:43:21.954	2026-04-02 23:43:24.253	\N	\N	\N	\N	\N	\N	\N	\N	\N
894f9b73-bbf0-476b-bf71-b8ec302e47f6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	u5 i5fivrri6vi66kfvkvyfoc6f	2026-04-02 23:45:16.695	2026-04-02 23:45:18.217	\N	\N	\N	\N	\N	\N	\N	\N	\N
02d16193-ac27-4949-96d1-812b88fed0ce	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	teste de vites	2026-04-02 23:57:50.853	2026-04-02 23:57:53.39	\N	\N	\N	\N	\N	\N	\N	\N	\N
478d1705-eecb-48fe-933a-f17f30aba497	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	86dfo6oy	2026-04-02 23:57:56.119	2026-04-02 23:57:56.201	\N	\N	\N	\N	\N	\N	\N	\N	\N
4e79b2e6-8032-43ef-b814-eea5da3112de	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	o7fflyfyl	2026-04-02 23:57:58.374	2026-04-02 23:57:58.403	\N	\N	\N	\N	\N	\N	\N	\N	\N
43c560a9-93b1-42cf-89c3-1134ce35c716	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	i6yfkkyflyfl7	2026-04-02 23:58:02.525	2026-04-02 23:58:02.602	\N	\N	\N	\N	\N	\N	\N	\N	\N
369d87c8-a110-44c6-b3ba-083c99174351	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	luflulyf7fl7fo7f	2026-04-02 23:58:05.397	2026-04-02 23:58:05.425	\N	\N	\N	\N	\N	\N	\N	\N	\N
55a18a83-77bc-46af-ba4e-eb98203b4c6e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	rtyyuufufufuffuufufuf	2026-04-03 00:02:21.995	2026-04-03 00:02:22.252	\N	\N	\N	\N	\N	\N	\N	\N	\N
bea84e5a-e2fb-420b-aef1-525a6ff42ef7	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	igigggugug	2026-04-03 00:02:26.251	2026-04-03 00:02:26.363	\N	\N	\N	\N	\N	\N	\N	\N	\N
f7eb1744-2c38-4bee-bcc0-e2ed6dfca9e1	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	fhhgfggyy777778tt8t88yy8	2026-04-03 00:04:49.999	2026-04-03 00:04:50.075	\N	\N	\N	\N	\N	\N	\N	\N	\N
430c968f-70fd-49c6-ad65-1b507e59485d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	8r8r8g8	2026-04-03 00:07:07.171	2026-04-03 00:08:41.84	\N	\N	\N	\N	\N	\N	\N	\N	\N
9dba8a03-37c0-423b-9bb8-91d05a161e4c	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	igogoho	2026-04-03 00:07:09.549	2026-04-03 00:08:41.84	\N	\N	\N	\N	\N	\N	\N	\N	\N
e2180df3-2641-4951-9080-356927d7f122	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	igigogogogohh	2026-04-03 00:07:11.561	2026-04-03 00:08:41.84	\N	\N	\N	\N	\N	\N	\N	\N	\N
2ebed1e6-eea3-4674-97d7-6cce4460ea57	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	igigigiggufufufifigigigigog	2026-04-03 00:07:15.501	2026-04-03 00:08:41.84	\N	\N	\N	\N	\N	\N	\N	\N	\N
d0d130a9-8b49-4f58-b5c7-d24c65f134d6	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	salut dany	2026-04-03 00:19:56.827	2026-04-03 00:20:37.026	\N	\N	\N	\N	\N	\N	\N	\N	\N
cd130a07-49a6-413e-bc78-271b36a7faab	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	ca marche plus	2026-04-03 00:20:27.445	2026-04-03 00:20:37.026	\N	\N	\N	\N	\N	\N	\N	\N	\N
054a8f0b-9cbb-40c9-b3ee-045fec756815	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	jfjj	2026-04-03 00:20:42.97	2026-04-03 00:20:43.078	\N	\N	\N	\N	\N	\N	\N	\N	\N
f2bd3f8f-c02f-4f73-a030-fa770969358e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ufur7rf7f7og8t8t8tg8g88g88g8if	2026-04-03 00:08:54.098	2026-04-03 04:37:23.973	\N	\N	\N	\N	\N	\N	\N	\N	\N
c7bdd204-a165-43e1-8bed-dfd8f7f1dff8	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	igiggiggigjhguuuuyhhhyihiihohohohho	2026-04-03 00:09:04.635	2026-04-03 04:37:23.973	\N	\N	\N	\N	\N	\N	\N	\N	\N
51a08b35-9fd7-486e-b4ed-ebc47fdf2fdf	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ihohohp	2026-04-03 00:09:06.634	2026-04-03 04:37:23.973	\N	\N	\N	\N	\N	\N	\N	\N	\N
66d71737-d462-42e3-9cc6-793821b099cf	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	bonjours  Cherie	2026-04-03 04:42:47.296	2026-04-03 04:42:57.019	\N	\N	\N	\N	\N	\N	\N	\N	\N
5f7cffe5-8cb7-4a88-b815-9d307f4585c4	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	salut	2026-04-03 04:43:02.98	2026-04-03 04:43:03.108	\N	\N	\N	\N	\N	\N	\N	\N	\N
72040bd5-17ca-4b5a-adc9-069a14b0fe56	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	Je T aime	2026-04-03 04:37:31.345	2026-04-03 04:43:14.743	\N	\N	\N	\N	\N	\N	\N	\N	\N
8bc0467a-4178-4dad-b7f4-16dad0ea4586	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	je taime	2026-04-03 04:41:04.77	2026-04-03 04:43:14.743	\N	\N	\N	\N	\N	\N	\N	\N	\N
a43c3ec5-e741-412b-9b01-9cb0c13fc877	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	coucou	2026-04-03 04:43:17.719	2026-04-03 04:43:17.744	\N	\N	\N	\N	\N	\N	\N	\N	\N
e1f9d1bb-d82d-4288-903e-d76b73deb11d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	teste de vitesse	2026-04-03 04:43:29.839	2026-04-03 04:43:29.861	\N	\N	\N	\N	\N	\N	\N	\N	\N
455bccfa-0c67-4fcd-832c-29d2aa01df42	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	tesbfndkkd	2026-04-03 04:43:38.565	2026-04-03 04:43:38.637	\N	\N	\N	\N	\N	\N	\N	\N	\N
664c7117-b363-4e8e-acc4-849c25fdfa6c	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	hjjjttj u uuuyyuu7	2026-04-03 04:43:45.484	2026-04-03 04:43:45.647	\N	\N	\N	\N	\N	\N	\N	\N	\N
cf226bde-c292-4c0e-9648-c64d85300bc0	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	hhhh	2026-04-03 04:43:47.475	2026-04-03 04:43:47.525	\N	\N	\N	\N	\N	\N	\N	\N	\N
cd0848f2-6986-405a-bd9b-8f2486326b0b	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	uu3ryhj	2026-04-03 04:43:49.908	2026-04-03 04:43:50.011	\N	\N	\N	\N	\N	\N	\N	\N	\N
20190425-cd7d-44f9-ae94-fb56d6ce1083	0c9fb139-6a31-40ff-bdf5-b541d3c010ec	fc758d78-e3c2-4ea7-a489-8e2886635f13	gjkkk	2026-04-03 04:43:51.815	2026-04-03 04:43:51.986	\N	\N	\N	\N	\N	\N	\N	\N	\N
fddb1706-c5eb-464f-8228-567f53cd472d	a980a82e-7a36-407b-ad1f-7cca92e60894	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	tainalika	2026-04-03 04:44:28.221	2026-04-03 04:44:41.44	\N	\N	\N	\N	\N	\N	\N	\N	\N
154140a3-10f5-4d63-b6a5-b80ea3916d1a	a980a82e-7a36-407b-ad1f-7cca92e60894	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	hhdjjsjsjs	2026-04-03 04:44:36.653	2026-04-03 04:44:41.44	\N	\N	\N	\N	\N	\N	\N	\N	\N
432ec025-c3e7-4537-be80-801ef6222486	a980a82e-7a36-407b-ad1f-7cca92e60894	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	jdjsjsjjz	2026-04-03 04:44:39.242	2026-04-03 04:44:41.44	\N	\N	\N	\N	\N	\N	\N	\N	\N
409bd9fc-004f-4189-a5cb-fa72c9305b42	a980a82e-7a36-407b-ad1f-7cca92e60894	f261a10b-c29c-4bd3-a413-bf99ee82cdb0	❤️	2026-04-03 04:44:51.082	2026-04-03 04:44:51.129	\N	\N	\N	\N	\N	\N	\N	\N	\N
2ccd597e-1de9-471b-b94b-32b97b5d273e	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 12:01:37.302	2026-04-05 12:01:44.273	\N	\N	\N	\N	\N	\N	\N	\N	\N
ae70478a-7547-492d-bde2-dbd993464dd8	ef81fc17-6f61-4491-85e5-134bba18f08d	b718efee-173e-441b-98f3-364b40c05e73	oui 👍	2026-04-05 12:02:01.011	2026-04-05 12:02:06.277	\N	\N	\N	\N	\N	\N	\N	\N	\N
f520a19b-6e69-413f-95e6-c6db41735f4d	89da74d8-5b34-4b39-b0b6-c2271c3c03b5	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 12:02:19.878	2026-04-05 12:02:30.688	\N	\N	\N	\N	\N	\N	\N	\N	\N
c44aab69-9559-4359-b2ae-753ccf28fe39	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	Bojour	2026-04-05 12:11:54.132	2026-04-05 12:11:54.197	\N	\N	\N	\N	\N	\N	\N	\N	\N
9ac97e59-4b63-491c-a910-6511572e2ca8	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	salut	2026-04-05 12:12:07.074	2026-04-05 12:12:07.191	\N	\N	\N	\N	\N	\N	\N	\N	\N
86db3873-f111-402b-ab90-7d84ee0a8d64	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	%%%%%%%%%%%%%%%%%	2026-04-05 12:20:12.8	2026-04-05 12:20:12.858	\N	\N	\N	\N	\N	\N	\N	\N	\N
51f835ee-badc-4177-9da3-d123795017ae	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 12:27:56.219	2026-04-05 12:28:03.222	\N	\N	\N	\N	\N	\N	\N	\N	\N
19aaaf4e-959b-4779-9fda-c62b91e2ad4e	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 12:35:51.07	2026-04-05 12:35:57.337	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
8ae648de-5663-4517-8daf-c503f9cc54f8	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oui	2026-04-05 12:39:17.249	2026-04-05 12:39:17.343	\N	\N	\N	\N	\N	\N	\N	\N	\N
07b9aabb-ba1a-41bf-a342-8dc7d5491f6a	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oui	2026-04-05 12:39:23.473	2026-04-05 12:39:23.551	\N	\N	\N	\N	\N	\N	\N	\N	\N
fc5368f0-b622-4266-a659-475753b943cc	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	combien	2026-04-05 12:42:48.283	2026-04-05 12:42:51.189	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
b1443bc7-000f-4da8-8586-010fe78ce881	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	merci	2026-04-05 12:43:28.692	2026-04-05 12:43:28.812	\N	\N	\N	\N	\N	\N	\N	\N	\N
715ae500-52ff-49d1-880b-6138cdfd55fc	9d9f9e58-60ce-46d5-b43e-6eb71afbc33a	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 13:43:57.837	2026-04-05 13:44:10.905	c79d01a5-8872-4e86-b588-9e6c98b53bd2	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775282364/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282360011?_a=BAMAOGfk0	145000 MGA	Moto • Disponible	gente moto	\N	\N	\N	\N
9276cc21-af57-4b6c-a710-359a788b64fb	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oui	2026-04-05 13:44:20.537	2026-04-05 13:44:21.635	\N	\N	\N	\N	\N	\N	\N	\N	\N
de807106-d2de-4fe5-bce2-79df061f0a08	9d9f9e58-60ce-46d5-b43e-6eb71afbc33a	fc758d78-e3c2-4ea7-a489-8e2886635f13	afaka miady varotra ve	2026-04-05 13:44:37.019	2026-04-05 13:44:37.91	c79d01a5-8872-4e86-b588-9e6c98b53bd2	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775282364/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282360011?_a=BAMAOGfk0	145000 MGA	Moto • Disponible	gente moto	\N	\N	\N	\N
1f1ae75f-3698-4a5b-9c58-86a2f48eea9e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oui afaka ka	2026-04-05 13:51:21.434	2026-04-05 16:22:00.921	\N	\N	\N	\N	\N	\N	\N	\N	\N
38a429d2-ea7e-42d0-bf0a-090114cb55c7	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ao ve o	2026-04-05 13:53:53.526	2026-04-05 16:22:00.921	\N	\N	\N	\N	\N	\N	\N	\N	\N
3bdd6ae9-5028-46a4-9609-5bb53f7c59c6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	aot ve o	2026-04-05 13:55:01.98	2026-04-05 16:22:00.921	\N	\N	\N	\N	\N	\N	\N	\N	\N
b91b2c2e-6348-4757-a821-5658fd823e40	bb05bd3a-677a-4a81-abdf-61f81f3ba09b	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 16:22:01.061	2026-04-05 16:22:06.829	4bae1fb8-7119-4588-a44c-7c98cd77fb2e	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775283001/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282995434?_a=BAMAOGfk0	420000 MGA	telephone • Disponible	Real me	\N	\N	\N	\N
33003799-5b25-4f3d-a7e2-a194673df424	bb05bd3a-677a-4a81-abdf-61f81f3ba09b	fc758d78-e3c2-4ea7-a489-8e2886635f13	any ve	2026-04-05 16:22:14.035	2026-04-05 16:22:15.786	4bae1fb8-7119-4588-a44c-7c98cd77fb2e	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775283001/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282995434?_a=BAMAOGfk0	420000 MGA	telephone • Disponible	Real me	\N	\N	\N	\N
5645ae9a-fad2-4ebc-a8f6-90b713f722b9	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ouiu	2026-04-05 16:22:22.635	2026-04-05 16:22:22.782	\N	\N	\N	\N	\N	\N	\N	\N	\N
18c076ab-fc9c-421e-95d9-69183a85cb49	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-05 16:24:01.269	2026-04-05 16:27:44.91	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
84f3fa5f-d2ed-4c8b-882e-e35d621d5b5a	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	bonjour	2026-04-06 13:25:22.001	2026-04-06 13:25:29.427	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
d1ba4315-a731-4fe4-98c0-ebf6ab421c43	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	hello	2026-04-06 13:30:22.714	2026-04-06 13:40:06.946	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
ac98ca7d-35c8-4dc0-9199-4ce39372b0c1	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	youu	2026-04-06 13:39:29.926	2026-04-06 13:40:06.946	\N	\N	\N	\N	\N	\N	\N	\N	\N
64930655-efd1-43fc-ab97-896657b2356c	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	ok ok	2026-04-06 13:34:14.439	2026-04-06 13:40:06.946	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
f6bf5b27-2f03-4c01-8e83-2faac0708610	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-06 13:39:35.476	2026-04-06 13:40:06.946	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
d33f54c8-0f9c-4d80-88db-a6ec60d5313f	ef81fc17-6f61-4491-85e5-134bba18f08d	fc758d78-e3c2-4ea7-a489-8e2886635f13	bonjour	2026-04-06 13:44:02.511	2026-04-06 13:44:04.227	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
382b30d4-4114-42d8-9c75-143f37a7d7b4	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-06 13:55:11.789	2026-04-06 13:55:16.921	1d3d6860-131f-4c8e-aa45-737a0f27d81b	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636953?_a=BAMAOGfk0	450 000 MGA	telephone • Disponible	oppo renault 5 pro	\N	\N	\N	\N
d8f311b3-7c0e-4c74-90c6-9f4e65f04151	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	de otrinona	2026-04-06 13:55:23.44	2026-04-06 13:55:23.479	\N	\N	\N	\N	\N	\N	\N	\N	\N
90194dc0-99ca-4e4f-82aa-117354e85ff4	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	eny ary	2026-04-06 14:09:48.699	2026-04-06 15:11:16.934	\N	\N	\N	\N	\N	\N	\N	\N	\N
412e18b2-3392-4175-a6d2-38a6f55f209a	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-08 02:16:43.26	2026-04-08 02:18:11.254	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4 000 000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
188492ac-4952-41e6-b0d1-f94cf53c1dd0	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	bonjour	2026-04-13 16:30:55.266	2026-04-13 16:30:55.387	\N	\N	\N	\N	\N	\N	\N	\N	\N
cf23c02d-c412-4f96-96c8-83521851db71	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	dimampolo	2026-04-13 17:29:59.06	2026-04-13 17:34:32.446	\N	\N	\N	\N	\N	\N	\N	\N	\N
8009c701-b27c-41e3-8b21-a61db3c7806e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	io	2026-04-13 17:36:58.395	2026-04-13 17:36:58.48	\N	\N	\N	\N	\N	de otrinona	d8f311b3-7c0e-4c74-90c6-9f4e65f04151	DAMA Dany	fc758d78-e3c2-4ea7-a489-8e2886635f13
3f280a3c-0a94-4ca9-82bb-ae8d741798ac	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	eka	2026-04-13 17:37:19.562	2026-04-13 17:37:19.921	\N	\N	\N	\N	\N	afaka miady varotra ve	de807106-d2de-4fe5-bce2-79df061f0a08	DAMA Dany	fc758d78-e3c2-4ea7-a489-8e2886635f13
19644be5-1cf7-4f84-b216-d3e36f11b817	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	yoo	2026-04-13 17:46:07.417	2026-04-13 17:48:45.871	\N	\N	\N	\N	\N	youu	ac98ca7d-35c8-4dc0-9199-4ce39372b0c1	DAMA Dany	fc758d78-e3c2-4ea7-a489-8e2886635f13
4702ab23-1d40-4349-91bf-d2a87ae5421e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ejjejjzjzjz	2026-04-13 17:51:48.972	2026-04-13 17:51:49.04	\N	\N	\N	\N	\N	\N	\N	\N	\N
6c05a9ae-1525-4faa-93c1-081d04825065	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hskkzz	2026-04-13 17:51:58.217	2026-04-13 17:51:58.265	\N	\N	\N	\N	\N	\N	\N	\N	\N
6d8eb7dc-6c19-4bd0-9e88-fe21d3106058	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hzjz	2026-04-13 17:52:01.788	2026-04-13 17:52:01.874	\N	\N	\N	\N	\N	\N	\N	\N	\N
8645ce45-ec83-4236-b8fb-870a7efa9053	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	gsjkz	2026-04-13 17:52:09.294	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
ee962ee7-6e29-4be3-83c0-b87f9b4cdcbc	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jzjhz	2026-04-13 17:52:11.28	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
daad1d9e-40bd-4c87-8be6-909071403a58	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hzzozpzhehz	2026-04-13 17:52:15.721	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
4904cc0b-1331-43b0-aa42-866b51467057	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hshshhshz	2026-04-13 17:52:23.334	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
e9bcc93d-9e3b-4fea-8596-209602cc5cca	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	zjzzizgzjdgzhzhzhz	2026-04-13 17:52:29.912	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
a9b5ce5f-71fc-4afa-97e1-369bf1ca868e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hhzhzzhhehhejzjzo ekziizcz zuzuzihzjz zhzhz	2026-04-13 17:52:41.545	2026-04-13 17:52:45.956	\N	\N	\N	\N	\N	\N	\N	\N	\N
82c3082c-2560-4c1b-875f-22065eaf0198	58e36424-de24-4007-88f3-8da16709cf7a	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	Cet article est toujours disponible ?	2026-04-19 16:13:57.865	2026-04-19 16:14:07.008	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4 000 000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
8649bd73-f9d1-49b7-9044-cc992cca9298	58e36424-de24-4007-88f3-8da16709cf7a	b718efee-173e-441b-98f3-364b40c05e73	oui c est disponible	2026-04-19 16:14:26.837	2026-04-19 16:14:26.875	\N	\N	\N	\N	\N	\N	\N	\N	\N
2e28a5bb-875d-446e-8d29-38e68176ada6	58e36424-de24-4007-88f3-8da16709cf7a	b718efee-173e-441b-98f3-364b40c05e73	ca va	2026-04-19 16:14:46.989	2026-04-19 16:14:50.979	\N	\N	\N	\N	\N	\N	\N	\N	\N
81ebd0d6-1f94-44ef-8ac0-36dc775fb6af	58e36424-de24-4007-88f3-8da16709cf7a	b718efee-173e-441b-98f3-364b40c05e73	enw tsy connecte	2026-04-19 16:17:32.289	2026-04-19 16:19:08.217	\N	\N	\N	\N	\N	\N	\N	\N	\N
993e2c75-a0fc-44dd-b58a-7a0d48092fe5	58e36424-de24-4007-88f3-8da16709cf7a	b718efee-173e-441b-98f3-364b40c05e73	dhhehehehhehe	2026-04-19 16:21:34.052	2026-04-19 16:21:39.118	\N	\N	\N	\N	\N	\N	\N	\N	\N
5db466b1-6ecd-430a-89bf-d63ac8258aaf	eb4f3a52-78e6-4091-86ff-27067139f577	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	teste	2026-04-19 16:20:29.48	2026-04-20 17:09:23.504	\N	\N	\N	\N	\N	\N	\N	\N	\N
1de94002-cf4e-448d-a8fe-8a863923925d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	ato ve o	2026-04-19 16:17:16.582	2026-04-20 17:32:53.56	\N	\N	\N	\N	\N	\N	\N	\N	\N
6cbc4bc4-3a00-45ae-88f6-ddd810b2ed29	58e36424-de24-4007-88f3-8da16709cf7a	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	mana	2026-04-19 16:38:59.376	2026-04-20 17:33:00.68	\N	\N	\N	\N	\N	\N	\N	\N	\N
cb927868-66e5-47b5-ab67-820fbb11c191	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	vdbslz	2026-04-23 23:55:30.999	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
a452bc2b-256a-4fe7-8c40-2f59da2a9bee	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	g GJ ju	2026-04-23 23:56:05.533	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
3cd66653-cab5-4e8b-a498-25397c2ce412	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jxf I	2026-04-23 23:56:36.247	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
49702169-9f56-424c-b6b9-79a6b0632ba6	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	uritit	2026-04-23 23:56:43.349	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
41ec2e25-f4ef-487b-b94b-b8226743d3a7	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	uffri	2026-04-23 23:56:45.739	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
5855ad92-c85a-490e-9094-135e0c3d5928	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hjdje	2026-04-24 00:01:51.814	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
781af345-6cd3-42bb-9bb0-c4c8a5b774b5	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jdjzjz	2026-04-24 00:01:56.248	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
b4e8680d-4919-4f33-bc4c-48cd8623ffdc	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jzjz	2026-04-24 00:02:04.246	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
7f784196-704a-4ee8-88b6-e3b3f2684133	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	iziz	2026-04-24 00:02:07.19	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
64c933f9-4fa7-4e43-87ca-6a2e1e9a56d3	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hdjjzz	2026-04-24 00:04:22.212	2026-04-24 00:07:30.784	\N	\N	\N	\N	\N	\N	\N	\N	\N
ea7656bc-2020-476b-b4db-8f23eab06566	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdhfiudshfiushdfiuhdsf	2026-04-24 00:07:57.76	2026-04-24 00:07:57.96	\N	\N	\N	\N	\N	\N	\N	\N	\N
2779ca9c-b517-4105-bd03-fba1e5ecc1dc	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdhfsidufhisd	2026-04-24 00:08:08.017	2026-04-24 00:08:08.907	\N	\N	\N	\N	\N	\N	\N	\N	\N
9739cb93-7311-4a0d-b1fc-4fe299e31a47	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdjfiosjdf	2026-04-24 00:09:05.55	2026-04-24 00:09:05.786	\N	\N	\N	\N	\N	\N	\N	\N	\N
62b0d6d4-7572-4456-9882-6393d0c8323d	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfsdiof	2026-04-24 00:11:01.587	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
ed9d1a78-2cc3-40aa-9f51-3094b9b6dd15	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	ssdfd	2026-04-24 00:11:15.125	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
9299f595-29ca-4dde-b9fc-f7b1ccf6440e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	dsfdfsdf	2026-04-24 00:11:23.552	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
1775a68e-483d-40c4-82a9-70c8a5377fae	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jsjzjjzjz	2026-04-24 00:12:06.627	2026-04-24 00:12:06.653	\N	\N	\N	\N	\N	\N	\N	\N	\N
cf127aca-21bd-48ad-9f08-a8449406b55e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfsdfsdf	2026-04-24 00:11:25.399	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
8a0f5d1e-3bb4-4920-a7eb-06c31de2e382	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	fsdf	2026-04-24 00:11:26.754	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
68407b9f-fd72-4d42-ba41-0aeb95feff9a	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdf	2026-04-24 00:11:28.063	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
44b7b807-e8b9-440d-a8b4-347430834f01	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sd	2026-04-24 00:11:29.134	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
e1fcb83c-9510-4540-9e06-89bfb1351e6f	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	sdfdsf	2026-04-24 00:11:33.101	2026-04-24 00:12:01.674	\N	\N	\N	\N	\N	\N	\N	\N	\N
72903360-8493-4c1b-951d-f1ccb96bd918	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	hjzjz	2026-04-24 00:15:02.813	2026-04-26 03:47:16.913	\N	\N	\N	\N	\N	\N	\N	\N	\N
fe923b4f-1a8f-40d4-a2f7-43664b0bb2c7	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	jekzhaa	2026-04-24 01:05:19.56	2026-04-26 03:47:16.913	\N	\N	\N	\N	\N	\N	\N	\N	\N
d7749642-c2ab-44c2-b63e-7bdcb9f42f0d	aaceea95-27ca-4eff-a37c-246107bc51aa	9b3b238f-3e67-4073-9b6b-afbd3731f195	Cet article est toujours disponible ?	2026-04-26 09:52:05.728	2026-04-26 09:52:14.223	3a4a58b8-8f96-42dd-b14f-f0ba045747e4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4 000 000 MGA	Moto • Disponible	MOTO New Mada	\N	\N	\N	\N
a43ae5ef-e379-4423-9146-d20085be4ad4	aaceea95-27ca-4eff-a37c-246107bc51aa	b718efee-173e-441b-98f3-364b40c05e73	oui	2026-04-26 09:52:20.291	2026-04-26 09:52:20.362	\N	\N	\N	\N	\N	\N	\N	\N	\N
48478fad-d51f-4ef8-9cf2-5e9539ee9e93	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	Bonjour izay ianao vao en ligne	2026-04-26 03:47:29.232	2026-04-27 17:13:59.342	\N	\N	\N	\N	\N	\N	\N	\N	\N
f417d7ba-cb48-4e72-b612-12d0f36f6bfc	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	tsy mamaly	2026-04-26 03:47:49.476	2026-04-27 17:13:59.342	\N	\N	\N	\N	\N	\N	\N	\N	\N
ed6558bc-f811-4a12-9ff6-05a7786eab58	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	a_za$	2026-04-26 03:48:05.503	2026-04-27 17:13:59.342	\N	\N	\N	\N	\N	\N	\N	\N	\N
862cc894-0cc3-4966-93be-e31457939804	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	bonjour	2026-04-27 17:13:54.993	2026-04-27 17:13:59.342	\N	\N	\N	\N	\N	\N	\N	\N	\N
63e69852-b46c-469b-903e-c8b6a62ee44e	6f944b8f-5750-4974-b8cb-a4c71f75ac07	fc758d78-e3c2-4ea7-a489-8e2886635f13	Cet article est toujours disponible ?	2026-04-27 17:14:08.594	2026-04-27 17:14:09.151	30e26f74-1462-4829-bb70-beea516822f3	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284309921?_a=BAMAOGfk0	10 000 MGA	femme • Disponible	boucle d oreil	\N	\N	\N	\N
dcc9aa29-1aeb-4eb6-a4e1-dec029e662b3	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	oui cherie	2026-04-27 17:14:36.083	2026-04-27 17:14:36.347	\N	\N	\N	\N	\N	\N	\N	\N	\N
f1c398fa-a42e-477f-9b73-d90d230cd509	6f944b8f-5750-4974-b8cb-a4c71f75ac07	b718efee-173e-441b-98f3-364b40c05e73	fttzz1	2026-04-27 17:14:44.337	2026-04-27 17:14:47.16	\N	\N	\N	\N	\N	\N	\N	\N	\N
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
\.


--
-- Data for Name: Order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Order" (id, "orderNumber", status, "subtotalAmount", "deliveryAmount", "totalAmount", "createdAt", "updatedAt", "buyerUserId", "sellerProfileId") FROM stdin;
e9daebd9-2af7-45cf-ade7-e4dc5fa0d4a9	BHB-SEED-001	DELIVERED	190000.00	15000.00	205000.00	2026-04-02 16:43:30.355	2026-04-02 16:43:30.355	b59f5d68-ec21-44d1-adf3-33786f0d3a35	6a138d49-94b3-4f80-9e9b-cf137bc0a245
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
\.


--
-- Data for Name: Product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Product" (id, title, description, "imageUrl", "priceAmount", "currencyCode", "isAvailable", "createdAt", "updatedAt", "sellerProfileId", "categoryId") FROM stdin;
prod-seed-iphone	iPhone 13 Pro Max	Smartphone premium avec excellent appareil photo.	https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=800	3150000.00	MGA	t	2026-04-02 16:43:30.301	2026-04-02 16:43:30.301	fca37388-adbd-44e3-b289-b98415b97eab	55dd2ced-64b4-4b70-8b06-7250b9fa2fe1
prod-seed-bag	Sac a main cuir premium	Mode feminine avec finition cuir elegante.	https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800	280000.00	MGA	t	2026-04-02 16:43:30.301	2026-04-02 16:43:30.301	508bbb87-c08e-411c-b550-d17e910b4cbb	f5df6305-1ab6-4f3b-9972-ebebc10053d5
prod-seed-perfume	Coffret parfum prestige	Selection premium pour cadeaux et occasions speciales.	https://images.unsplash.com/photo-1541643600914-78b084683601?w=800	190000.00	MGA	t	2026-04-02 16:43:30.302	2026-04-02 16:43:30.302	6a138d49-94b3-4f80-9e9b-cf137bc0a245	e28856dc-ae47-4d6f-abfc-d394b19793fa
prod-seed-chair	Chaise design minimaliste	Assise confortable pour salon ou bureau moderne.	https://images.unsplash.com/photo-1519947486511-46149fa0a254?w=800	145000.00	MGA	t	2026-04-02 16:43:30.301	2026-04-02 16:43:30.301	508bbb87-c08e-411c-b550-d17e910b4cbb	95c627c8-23ee-40eb-87b6-79d1d8256f8f
c79d01a5-8872-4e86-b588-9e6c98b53bd2	gente moto	gente  moto routière	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775282364/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282360011?_a=BAMAOGfk0	145000.00	MGA	t	2026-04-04 05:59:25.037	2026-04-04 05:59:25.037	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2712b453-15f3-4e50-a095-e5716fccb144
4bae1fb8-7119-4588-a44c-7c98cd77fb2e	Real me	realme vrai marque venant d'europe	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775283001/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775282995434?_a=BAMAOGfk0	420000.00	MGA	t	2026-04-04 06:10:02.096	2026-04-04 06:10:02.096	cddc0066-1179-4a16-aa8a-7edeea79d0bc	65e0a618-b863-4562-b1dd-319e3ef7a197
30e26f74-1462-4829-bb70-beea516822f3	boucle d oreil	hdlskzgzhjzjz	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284309921?_a=BAMAOGfk0	10000.00	MGA	t	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2a64e44f-b82c-451a-95b7-2562177e6c6a
1d3d6860-131f-4c8e-aa45-737a0f27d81b	oppo renault 5 pro	best description	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636953?_a=BAMAOGfk0	460000.00	MGA	t	2026-04-04 06:37:21.627	2026-04-08 02:10:58.66	cddc0066-1179-4a16-aa8a-7edeea79d0bc	65e0a618-b863-4562-b1dd-319e3ef7a197
3a4a58b8-8f96-42dd-b14f-f0ba045747e4	MOTO New Mada	moto soa be de soa be de tena soa be	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	4000000.00	MGA	t	2026-04-04 16:36:41.496	2026-04-20 19:31:21.435	cddc0066-1179-4a16-aa8a-7edeea79d0bc	2712b453-15f3-4e50-a095-e5716fccb144
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
\.


--
-- Data for Name: ProductImage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductImage" (id, "imageUrl", "sortOrder", "createdAt", "updatedAt", "productId") FROM stdin;
4275be1d-5aed-40b7-92f4-0a5c574b155a	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284309921?_a=BAMAOGfk0	0	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
a460358d-6c42-4d5e-ac5d-b9a6fe921c98	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284318/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310041?_a=BAMAOGfk0	1	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
5dd9478e-5379-466a-853a-b9e5950948cd	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284315/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310042?_a=BAMAOGfk0	2	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
8fbbfc24-a245-45ef-ad2d-8c7607891519	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284318/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310043?_a=BAMAOGfk0	3	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
981531a1-67ac-4f21-9d39-f835a9caf401	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310044?_a=BAMAOGfk0	4	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
63034843-6e06-4828-8abc-cd194da5cbbc	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284317/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310045?_a=BAMAOGfk0	5	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
5bcdbabe-1d2d-4001-8713-ffd4d98e81c4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284316/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310046?_a=BAMAOGfk0	6	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
24af59d7-545b-4378-8d79-fbab743c13f6	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284316/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284310047?_a=BAMAOGfk0	7	2026-04-04 06:31:58.454	2026-04-04 06:31:58.454	30e26f74-1462-4829-bb70-beea516822f3
890bfb84-e10c-42c5-abba-40a9aa4e5f63	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636953?_a=BAMAOGfk0	0	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
f5e29aee-a9a2-4fc1-84c6-15c13e351adb	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636961?_a=BAMAOGfk0	1	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
54cae2e0-e874-4632-a370-2856aa1e4ae4	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636966?_a=BAMAOGfk0	2	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
b76d4823-4c6d-4c7b-980f-f3d7c96c3c68	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636971?_a=BAMAOGfk0	3	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
d8758ed4-205c-41c2-8be8-04d00e959bce	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636976?_a=BAMAOGfk0	4	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
a092eb35-f392-4eee-b665-fd291342438e	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775284641/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775284636980?_a=BAMAOGfk0	5	2026-04-08 02:10:58.66	2026-04-08 02:10:58.66	1d3d6860-131f-4c8e-aa45-737a0f27d81b
760486c9-68ac-48e7-a5ec-f09c5d39d76b	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596223?_a=BAMAOGfk0	0	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
052ee540-7aa8-46f5-aa19-f5de7ab7d6b0	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596344?_a=BAMAOGfk0	1	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
5ec7d179-387b-4bf7-8a67-da92fc50a68c	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1775320601/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1775320596346?_a=BAMAOGfk0	2	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
42a63280-aa52-44e4-9bd1-cb5fd2ee28ed	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_1400,q_auto:good,w_1400/v1776713474/bahibo/products/cddc006611794a16aa8a7edeea79d0bc-product-1776713460907?_a=BAMAOGfk0	3	2026-04-20 19:31:21.435	2026-04-20 19:31:21.435	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
\.


--
-- Data for Name: ProductLike; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."ProductLike" (id, "createdAt", "userId", "productId") FROM stdin;
52ebac60-8a42-4b59-a8b8-dee8ca83dda6	2026-04-05 16:37:11.177	b718efee-173e-441b-98f3-364b40c05e73	c79d01a5-8872-4e86-b588-9e6c98b53bd2
18641624-d3ba-496a-9492-fac56928c3ab	2026-04-06 03:24:09.931	fc758d78-e3c2-4ea7-a489-8e2886635f13	c79d01a5-8872-4e86-b588-9e6c98b53bd2
a4933451-650d-4e9a-beb4-e01bbf01c0ee	2026-04-06 03:26:40.33	fc758d78-e3c2-4ea7-a489-8e2886635f13	1d3d6860-131f-4c8e-aa45-737a0f27d81b
6bd5ead5-70e8-435f-9d8a-69b48aef1c9d	2026-04-06 03:34:20.391	fc758d78-e3c2-4ea7-a489-8e2886635f13	4bae1fb8-7119-4588-a44c-7c98cd77fb2e
ca7a8067-d16e-41ea-abe2-91977f0f7bff	2026-04-06 03:49:34.169	fc758d78-e3c2-4ea7-a489-8e2886635f13	30e26f74-1462-4829-bb70-beea516822f3
d8acdcaa-eea4-413f-a121-a99b9be67225	2026-04-19 14:05:36.189	fc758d78-e3c2-4ea7-a489-8e2886635f13	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
ab59298e-bf65-4935-9014-432ab18d6f27	2026-04-19 16:41:01.101	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
e809e750-97fb-4cdd-938d-89cfe0ee3be7	2026-04-19 16:41:11.666	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	1d3d6860-131f-4c8e-aa45-737a0f27d81b
06badb85-feac-4efe-a500-119731c644f7	2026-04-27 17:08:17.68	b718efee-173e-441b-98f3-364b40c05e73	3a4a58b8-8f96-42dd-b14f-f0ba045747e4
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
\.


--
-- Data for Name: RefreshToken; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."RefreshToken" (id, "tokenHash", "expiresAt", "createdAt", "userId") FROM stdin;
539e7737-986a-4d8c-8969-b79594c9e43b	$2a$10$qCrLcBrofcQSti82PNblBOYrNN6FphfFF65lfCr2Ku7YDCqoLwLf6	2026-04-09 16:46:26.437	2026-04-02 16:46:26.439	b59f5d68-ec21-44d1-adf3-33786f0d3a35
67de3886-c30d-48fb-95f6-d44b0c5aa9cd	$2a$10$zb8iIjfimG4bLt8/lw0it.T/SzvvEdCm.pa4fHDFe9H7md/8tIJNC	2026-05-24 04:13:46.631	2026-04-24 04:13:46.632	b718efee-173e-441b-98f3-364b40c05e73
08d742dd-7888-4d46-8a32-4030035820f9	$2a$10$kX1eJ0CTzuqiDZeIXzzl.u3qrbHireR62G4Wm18UpJcRVOglemPS2	2026-05-06 15:39:43.166	2026-04-06 15:39:43.168	fc758d78-e3c2-4ea7-a489-8e2886635f13
5c31f98e-06bf-4c3f-b182-4b5871025d56	$2a$10$wXDtrZwJiULUyyuV8PyWg./2QNx2ZozWNs2tQq.Fh7rjOfxR.maNy	2026-05-03 15:39:43.424	2026-04-03 15:39:43.425	b718efee-173e-441b-98f3-364b40c05e73
1db31245-c76b-415f-ae59-c2177062f9d9	$2a$10$/tfYKxks8VpMYIOUwCQrFe9Bl9hBvr/sKfRlPfonQIehWW25ZWcZu	2026-05-04 03:18:39.552	2026-04-04 03:18:39.553	fc758d78-e3c2-4ea7-a489-8e2886635f13
be118647-ca45-45f5-9578-f0bb6017fb8d	$2a$10$.UDug2U9lyFMqYwpwdigO.aWsWFElgnTHuq3Nnofx6Q8fqotMvCp.	2026-05-04 03:27:45.037	2026-04-04 03:27:45.039	fc758d78-e3c2-4ea7-a489-8e2886635f13
e73861c8-9b68-4072-ae16-3879394ecd0e	$2a$10$PJiHVr05MQf3qlYzdWBJz.5y.YISc8.xiefuu7a.EaraZ4CNCnzuC	2026-05-04 03:54:55.981	2026-04-04 03:54:55.983	fc758d78-e3c2-4ea7-a489-8e2886635f13
26513d54-f138-4f01-bab2-ce2f01446bee	$2a$10$4E941lAEtgkPXr/jVNBfpe5DtNwbXBEcaWPtXBsmu1RUcAlAUZ6nK	2026-05-06 16:02:42.084	2026-04-06 16:02:42.086	fc758d78-e3c2-4ea7-a489-8e2886635f13
84517d2e-29eb-4cd6-8ee3-e6df30c19700	$2a$10$OPTgkNJljSPpGPC603sIMeqb5weoHAJSWUYse.0CI1Q.DHpCt0xuG	2026-05-13 17:00:08.671	2026-04-13 17:00:08.672	fc758d78-e3c2-4ea7-a489-8e2886635f13
9c1e4711-ddcb-403f-8a63-62b658d95616	$2a$10$hVoFlFjO8MTqSeNOm/k88ecgaj/y6LCj0aLbVx/IFoDBa9QGqxXK6	2026-05-04 04:05:51.582	2026-04-04 04:05:51.584	b718efee-173e-441b-98f3-364b40c05e73
295e1deb-354c-42a8-add7-128d638da9ac	$2a$10$dKsGi1n98ROunEkmFQrWOustkBNTExQ7dQrWBwOidmyOXJsngCmya	2026-05-02 22:32:25.592	2026-04-02 22:32:25.594	b718efee-173e-441b-98f3-364b40c05e73
64a16e52-c981-43bf-b44c-cee157e10f0f	$2a$10$tw9.NUiWX1rv5Yhz6pjqN.gCuQ9HfvIYUpSNWgTYq01x5dpRC1x0W	2026-05-04 04:12:06.545	2026-04-04 04:12:06.547	fc758d78-e3c2-4ea7-a489-8e2886635f13
83a8653a-c381-4183-83d4-cb60d119c421	$2a$10$M5Secv/Utu237vHnpchyBOrvGc5iWG41RC4oqOyaSsrgB0/AqiVVe	2026-05-04 04:38:39.362	2026-04-04 04:38:39.363	fc758d78-e3c2-4ea7-a489-8e2886635f13
f2358608-da00-467d-ba5e-8df1dcd3c68d	$2a$10$jgtg2CwNMbDBlzqBCk46/.HhFvdUILWfh1j5GSeZC6AcX/r3gKKUK	2026-05-08 18:54:23.063	2026-04-08 18:54:23.064	b718efee-173e-441b-98f3-364b40c05e73
00c77cc9-8de9-42ab-9dd5-a4fe801866c0	$2a$10$SqhppX2B56TFwXej166xt.YUxeSCcG4QumiJa0BzUA9wZ65tpnHqm	2026-05-04 05:33:07.575	2026-04-04 05:33:07.576	fc758d78-e3c2-4ea7-a489-8e2886635f13
3529c643-4d88-40a1-a839-3513a8d29bd1	$2a$10$o9ytbhlpxVSauPtE6TCI6uTyDrmRSgWnOBKWudJyJvo3X7TuECMFe	2026-05-06 19:33:50.267	2026-04-06 19:33:50.268	b718efee-173e-441b-98f3-364b40c05e73
6cdb7bb6-fffa-4fc0-bdd3-9c1833162b6d	$2a$10$0IOAttCfaL2zOOxNJnRSF.88o5AjjiJaS.uFoH65A1GNkf1VBbpey	2026-05-02 23:39:03.499	2026-04-02 23:39:03.5	fc758d78-e3c2-4ea7-a489-8e2886635f13
65339604-bc76-49c1-bb8e-2fba7ccea283	$2a$10$HjBr5bir5mzUFohzv2T0eemtfLiu3PjyWIO73P8/t3S2d9uEd77kC	2026-05-06 03:57:07.084	2026-04-06 03:57:07.085	b718efee-173e-441b-98f3-364b40c05e73
6dbabb4d-491e-4c3d-8008-4149407b925c	$2a$10$hOrHZj/n7aLbpxwQNZ1a1uNygsPjugxZCV2tvPZuZBVQ.39QoRhiK	2026-05-08 09:37:32.972	2026-04-08 09:37:32.973	fc758d78-e3c2-4ea7-a489-8e2886635f13
73b33446-cd05-47a9-95cd-c881e9334602	$2a$10$6Dc4eeX5wBLJl3ZNVuE0S.lAgx3t9x6l7aLH8K8JrxAEGXDaoRETO	2026-05-03 00:08:27.757	2026-04-03 00:08:27.758	b718efee-173e-441b-98f3-364b40c05e73
da430875-5719-4c8e-9818-ac3b42fdb14a	$2a$10$5r20llRGXgtBc1D46BcFD.VVX3FbZhg9.ojHhreDCJNcmVTi7dihK	2026-05-03 00:08:31.092	2026-04-03 00:08:31.094	fc758d78-e3c2-4ea7-a489-8e2886635f13
ff675345-49b2-4687-b6fb-3ae8f88e4e31	$2a$10$LSCXNLvMnAnDjUBnlks/q.hqDOPy3e/3.IQWiu7WQQ6FCdIssxipG	2026-05-13 08:18:53.683	2026-04-13 08:18:53.685	b718efee-173e-441b-98f3-364b40c05e73
3dac5f1c-665d-433b-9ff8-8b063fcd4c02	$2a$10$/vObzGnsJ7fzPBxguEfRJu.5IXhqvZwX.KKig3b6kvGkaAmWvpCv6	2026-05-03 04:42:25.807	2026-04-03 04:42:25.808	f261a10b-c29c-4bd3-a413-bf99ee82cdb0
6eeaf758-3b5f-4138-a540-69ddd2cb7dd2	$2a$10$2cJq1wvLkLihAp9e4uAMG.CZ41LN0KKgO/GFHVb75X9syt1G8UQEm	2026-05-08 10:05:49.91	2026-04-08 10:05:49.911	fc758d78-e3c2-4ea7-a489-8e2886635f13
6fdd33e4-d316-46ae-8724-7b2f69072b76	$2a$10$1V.RIJS3DLgvjv.hpnwDtO0H4unqCSGdkLJJhV5CSQ/GBv/nb9VV2	2026-05-04 06:37:47.919	2026-04-04 06:37:47.921	b718efee-173e-441b-98f3-364b40c05e73
a5a7a1a0-0b17-48ee-aea3-abe4a587307d	$2a$10$0QaIctRxDmHrgY0FBHQ.QusHqXlUTZ1F4xGpXdS46akpHGTyml/P6	2026-05-03 08:16:19.084	2026-04-03 08:16:19.086	b718efee-173e-441b-98f3-364b40c05e73
cddc7624-401b-4102-a763-a6692cb51c0b	$2a$10$uJja7kgUFaSPke1kUZgNA.pgHO.ZsL1FSYXUH0JYBCX4fowD19y5i	2026-05-05 14:31:34.588	2026-04-05 14:31:34.589	b718efee-173e-441b-98f3-364b40c05e73
63705aa7-2805-458f-8615-62005c371ae1	$2a$10$6t.r6SFjYY1iaCIpY2eAz.ZRuHJWpWNzzWZ5qu1dtQ.Hez7x7X/WK	2026-05-05 15:51:30.496	2026-04-05 15:51:30.497	b718efee-173e-441b-98f3-364b40c05e73
a5139616-c60c-4477-b3fd-552ec9382a52	$2a$10$FOirIA1EuYh0Le.Tjp8g1.mjfcCI5PmKCKijmI6EIFO8hKwRHt.NS	2026-05-13 19:54:35.763	2026-04-13 19:54:35.764	fc758d78-e3c2-4ea7-a489-8e2886635f13
fd085443-13bd-411a-ac8c-4a528a30c544	$2a$10$X9ATqyBUkijfwEyUrQwIQe0QOizgphsBBC0OqLePkf98XkkvLujEm	2026-05-03 10:16:39.547	2026-04-03 10:16:39.548	fc758d78-e3c2-4ea7-a489-8e2886635f13
b0a7c5ea-1543-4147-9755-e782dd94c2f8	$2a$10$SxpAY33g/dAu1UV2WagWDupUp97EessoabSoRHaVWCflHXot7jsEe	2026-05-06 13:43:33.363	2026-04-06 13:43:33.364	fc758d78-e3c2-4ea7-a489-8e2886635f13
13c3f06d-db99-4b08-a4fd-2a8ce22ec63c	$2a$10$Hzo315Al0MlGU/9d1Qm1DusIWk/s3p/aK4wT6mXatcOs/Q7.xpdP.	2026-05-07 16:03:44.163	2026-04-07 16:03:44.164	fc758d78-e3c2-4ea7-a489-8e2886635f13
0d8db97e-db65-49bd-9ffe-ea10ab3ea564	$2a$10$SuTL/gWNNPamp4iKgxpsRuWPLuBpgyBa9oZ8ymuhgnZBfnx2IHdSK	2026-05-07 16:04:29.027	2026-04-07 16:04:29.029	b718efee-173e-441b-98f3-364b40c05e73
b7b7d674-70b4-4cd1-ac16-484828f7d81b	$2a$10$K.E7EJXBk5qf6ZZoYnJw2uNs1xDonOYIye5ncqzwIiITfnGSuYhEG	2026-05-03 10:31:00.18	2026-04-03 10:31:00.181	b718efee-173e-441b-98f3-364b40c05e73
726fce2a-c275-46fd-9e30-75a40dc4d9b8	$2a$10$Y5DS8ixIvflBMPaQUX64CupmtZXPjOc7.9sqlNjiaJdI6YdHPf04K	2026-05-09 17:21:04.135	2026-04-09 17:21:04.136	b718efee-173e-441b-98f3-364b40c05e73
325f4acf-761c-4a93-8dcb-439d47ad837b	$2a$10$k.kp22xzNtmCUDY6S8TCEu0YRQnmCymgBQBU2EaoGcVPO64CgBtTi	2026-05-04 16:28:18.219	2026-04-04 16:28:18.22	b718efee-173e-441b-98f3-364b40c05e73
e765c56d-ef53-47a7-a3d9-e5e4aac29bfa	$2a$10$CjB3i4RWRtYYixHmHNSXQOj8tx70RveoeHDD4i64VYWak3tzzpJ.K	2026-05-04 16:28:40.603	2026-04-04 16:28:40.605	b718efee-173e-441b-98f3-364b40c05e73
a33ad8dc-df6a-484e-a3fa-90868839d0ee	$2a$10$cGU5mRYQsGBx6lMQf3BtIOer4lO/.MVR.vFTWypyoGM/.uo8G1akW	2026-05-04 16:31:25.408	2026-04-04 16:31:25.419	b718efee-173e-441b-98f3-364b40c05e73
a754178d-fde4-4a92-9e33-bbf935d44c9d	$2a$10$iSU2ArsR66MvgDfQatm81.LI4qju2psQxBgXTuPJ3adqcRsPLVtee	2026-05-04 16:34:04.738	2026-04-04 16:34:04.739	b718efee-173e-441b-98f3-364b40c05e73
938742dc-cff3-435d-ab00-724ea1247b45	$2a$10$p/ex5T8mcYULEafTAI5/ROiWcQj7OwHCOYcWKP1i2zc/hzKiomlxq	2026-05-06 14:46:54.217	2026-04-06 14:46:54.218	fc758d78-e3c2-4ea7-a489-8e2886635f13
9021f499-9362-4676-8de2-0e00baaf7f2e	$2a$10$iY135Evv2.xO2Zgf5oVf3eX2oPLLfJhM.B6zzPbsZlhCgoyGjcD2a	2026-05-08 16:25:58.463	2026-04-08 16:25:58.465	b718efee-173e-441b-98f3-364b40c05e73
2f1e3423-2088-4dd2-852d-1ce5f70f8513	$2a$10$/qFU1ndJdVj.GpkBdeTKTONLSdNsPBKwztd7KwHCuUS/9hWdP9YPq	2026-05-10 03:10:10.594	2026-04-10 03:10:10.595	fc758d78-e3c2-4ea7-a489-8e2886635f13
7398e414-3cc2-4f27-bf87-64586906f41e	$2a$10$8ADamPl7zEGlKPIdsNy18.gFpOgiWJa3i2MfHe1OKiRdYnVYwYbG2	2026-05-24 05:53:14.655	2026-04-24 05:53:14.657	fc758d78-e3c2-4ea7-a489-8e2886635f13
42f8bf53-b7dc-4243-9876-a9e8e2d5b233	$2a$10$HzyvZNIVaY0TS9JRpJyeHOyPoATM0FAolJhXWeFWqh5e91JnSi4l2	2026-05-20 19:57:01.84	2026-04-20 19:57:01.842	fc758d78-e3c2-4ea7-a489-8e2886635f13
a1343801-67ff-41bf-831a-44d40ffe5a56	$2a$10$EYghdZk6jX/D2p5RGVe1Mu/vF0SjbvNH9UEU9h2jaGnQQsNnJAxQO	2026-05-26 09:48:28.352	2026-04-26 09:48:28.354	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d
02155aef-2fa3-4e3a-8fe0-310e6c49e2c8	$2a$10$piUaHJUuRPH2PMOzlwWze.krgz0qwLWBihwSycBji9kUn0.X0N2aK	2026-05-26 09:50:54.292	2026-04-26 09:50:54.293	9b3b238f-3e67-4073-9b6b-afbd3731f195
62f75312-7f99-4832-91a5-cd45ad65aee4	$2a$10$ZvxlFPz.BDJar0sS50cYQOoBcHNLyuWOeKUtGgHGwExe7cQpScVra	2026-05-26 10:12:50.916	2026-04-26 10:12:50.92	b718efee-173e-441b-98f3-364b40c05e73
4ff94f4e-1aa6-4f6e-a70d-ebabb1e2920c	$2a$10$T5fmglRo.IE8kUiIZRmvgOjetQHFjd7k.4jy3HcOQ9HwHPAGWtEym	2026-05-24 00:23:08.924	2026-04-24 00:23:08.925	fc758d78-e3c2-4ea7-a489-8e2886635f13
3746669d-d0ae-4c42-8341-c1375d71ab02	$2a$10$iGWpNyH.32HwTh.tMP40WefbsbN9qELJpspqBkHER6jktozzmG0/2	2026-05-26 13:27:16.183	2026-04-26 13:27:16.184	fc758d78-e3c2-4ea7-a489-8e2886635f13
a6e8636b-0c36-4442-84fb-f04dde107e35	$2a$10$3wpEitUgsREgTQMQTYeL/OsgHNl.QaHUvY1wwfsPjQbpEfqKMPiG.	2026-05-26 13:56:16.867	2026-04-26 13:56:16.869	b718efee-173e-441b-98f3-364b40c05e73
8b0963ba-5358-4b13-af14-308dd50e5c65	$2a$10$TcP1XufAWMHBkExnN/xejezADVzuY3m5i6NHxSF0uuFlN1K17zT22	2026-05-26 14:12:00.383	2026-04-26 14:12:00.385	fc758d78-e3c2-4ea7-a489-8e2886635f13
befc5288-7dde-4fd2-b9d7-86c554ffc1fc	$2a$10$K7ikMgUgXts3cLpP.kzcReKPBLIUomAcstz6UqEQTTWTKHlqwrRXS	2026-05-26 14:36:01.968	2026-04-26 14:36:01.971	fc758d78-e3c2-4ea7-a489-8e2886635f13
59e26ecd-0e75-493e-a0bb-1701383aef3d	$2a$10$M5Xu4sBUz84fjq4VporHMOF9KasfcHzkxM2MF2VEvod/w2QRKt42i	2026-05-26 14:39:39.248	2026-04-26 14:39:39.25	fc758d78-e3c2-4ea7-a489-8e2886635f13
ce0abdb6-70c5-47d6-b9fe-dffaf8572e13	$2a$10$7OAzQ8mpv4CYRInq0MBA3uFAR7vcWzrpkvNJYTn1sSQvLsr4wnaxS	2026-05-24 04:07:32.61	2026-04-24 04:07:32.611	b718efee-173e-441b-98f3-364b40c05e73
80b1c7a5-8f65-4ae1-af4a-73c19190b628	$2a$10$DXpvB.UmpV0FJxNgTkXUZOJKhhLf5F6JLlHmaSwXeGlNyEQxGkBI.	2026-05-24 04:07:33.186	2026-04-24 04:07:33.187	b718efee-173e-441b-98f3-364b40c05e73
ee17b97b-fb3a-4b7d-8959-94b917631621	$2a$10$lhK0ZSRtrNTkF2Tee.MqN.EGtDtcTNVrrkaSqPhk7lXth1aKlszz6	2026-05-26 14:52:52.407	2026-04-26 14:52:52.409	b718efee-173e-441b-98f3-364b40c05e73
89100f9e-289e-48f8-854c-d347b1701cae	$2a$10$mSddH.Ti6sEdPFJMx6f5X.nGfBcNSD80jyk4OrxviB.1V4QNdV.8e	2026-05-26 14:55:38.376	2026-04-26 14:55:38.377	fc758d78-e3c2-4ea7-a489-8e2886635f13
b16e98d4-c304-42ce-8d15-b97f50a26d25	$2a$10$nbevy9koL.zxlPDnbJW2r.K4SBA2c3u17/kqo1hsQyBkmQYQmitwK	2026-05-26 16:45:33.475	2026-04-26 16:45:33.489	b718efee-173e-441b-98f3-364b40c05e73
596a4e1b-b22b-4228-971e-bf75c060e273	$2a$10$fgqW535M/GuucbmjeRSnHORth6NUAWmpB4bMOe.RouMWNTXei98Ly	2026-05-27 17:06:11.413	2026-04-27 17:06:11.415	b718efee-173e-441b-98f3-364b40c05e73
688e0beb-fa37-4c7a-93d0-dacaed40ccf9	$2a$10$k6vmLtNdRP7xLlGLrugabuLYa5/CmgNdQrrvGA8zmadQT7G.Qp/76	2026-05-27 17:13:40.738	2026-04-27 17:13:40.739	fc758d78-e3c2-4ea7-a489-8e2886635f13
c29be277-719e-4d4b-83bf-3b7e5eefbfb9	$2a$10$QEd1lQLeX4dgPqbt33o3PuWD89HSyWAc/9OsMxGcN.pviSSN8gVOO	2026-05-28 20:47:12.939	2026-04-28 20:47:12.94	b718efee-173e-441b-98f3-364b40c05e73
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
8250dc0d-cb38-4717-971f-4526870901f0	cddc0066-1179-4a16-aa8a-7edeea79d0bc	Vony Verronique en direct	Presentation produit	2026-04-27 17:16:05.271	2026-04-27 17:16:52.374	2026-04-27 17:16:52.373
\.


--
-- Data for Name: SellerProfile; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."SellerProfile" (id, "studioName", description, city, country, "createdAt", "updatedAt", "userId") FROM stdin;
508bbb87-c08e-411c-b550-d17e910b4cbb	Elanga Store	Mode et accessoires soigneusement selectionnes.	Toamasina	Madagascar	2026-04-02 16:43:30.135	2026-04-02 16:43:30.135	5beec21f-4030-41a6-b602-2c5228646d8d
fca37388-adbd-44e3-b289-b98415b97eab	Jojol Store	Boutique high-tech et smartphones premium.	Antananarivo	Madagascar	2026-04-02 16:43:30.135	2026-04-02 16:43:30.135	f299317e-35da-484f-a473-4a66c0adc02d
6a138d49-94b3-4f80-9e9b-cf137bc0a245	NalaK	Parfums, beaute et cadeaux premium.	Fianarantsoa	Madagascar	2026-04-02 16:43:30.136	2026-04-02 16:43:30.136	4af03bff-0bbc-46fd-8936-061181dbda80
cddc0066-1179-4a16-aa8a-7edeea79d0bc	Vony Verronique	\N	\N	\N	2026-04-04 04:58:22.363	2026-04-04 04:58:22.363	b718efee-173e-441b-98f3-364b40c05e73
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
b59f5d68-ec21-44d1-adf3-33786f0d3a35	+261341234567	Client Demo	$2a$10$f5H21IarnQaIXnrG1gAYAebcEKhjcveIgGcbG1sMUWhFN9YGNXZJ2	https://i.pravatar.cc/240?img=15	\N	CUSTOMER	t	2026-04-02 16:43:29.855	2026-04-02 16:43:29.855	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
f299317e-35da-484f-a473-4a66c0adc02d	+261340000111	Jojol Store	$2a$10$f5H21IarnQaIXnrG1gAYAebcEKhjcveIgGcbG1sMUWhFN9YGNXZJ2	https://i.pravatar.cc/240?img=18	\N	SELLER	t	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
5beec21f-4030-41a6-b602-2c5228646d8d	+261340000222	Elanga Store	$2a$10$f5H21IarnQaIXnrG1gAYAebcEKhjcveIgGcbG1sMUWhFN9YGNXZJ2	https://i.pravatar.cc/240?img=52	\N	SELLER	t	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
4af03bff-0bbc-46fd-8936-061181dbda80	+261340000333	NalaK	$2a$10$f5H21IarnQaIXnrG1gAYAebcEKhjcveIgGcbG1sMUWhFN9YGNXZJ2	https://i.pravatar.cc/240?img=47	\N	SELLER	t	2026-04-02 16:43:29.902	2026-04-02 16:43:29.902	\N	\N	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
f261a10b-c29c-4bd3-a413-bf99ee82cdb0	+261346484348	Verbose	$2a$10$EE0jsyZDrGmBDBcQ87bJsObedqyKHTjovgMQ/0KAvPCIr0M5BW0XW	\N	\N	CUSTOMER	t	2026-04-03 00:19:30.407	2026-04-03 00:19:30.407	+261	Madagascar	\N	\N	\N	\N	\N	\N	NONE	\N	\N	f	NONE	\N	\N	\N
b718efee-173e-441b-98f3-364b40c05e73	+261342307565	Vony Verronique	$2a$10$FVg4gDRhnWDHQSnK11l.Muh/p3co6KLEEhCS9GAee1a1fxkWmNome	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1775212066/bahibo/profile-avatars/261342307565-avatar-1775212059567?_a=BAMAOGfk0	\N	SELLER	t	2026-04-02 20:47:00.078	2026-04-28 20:48:51.495	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1775211995/bahibo/profile-covers/261342307565-cover-1775211988274?_a=BAMAOGfk0	Tananarive, Antananarivo Renivohitra	-18.941854	47.5294155	2026-04-26 03:49:49.534	2026-04-04 04:58:22.354	APPROVED	2026-04-03 17:58:20.854	\N	t	APPROVED	2026-04-06 15:45:33.235	2026-04-06 15:46:21.466	2026-04-28 20:48:51.493
f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	+261324965862	Juliana	$2a$10$E9x7KUr.eA6D8z1CW9wGWOXLVggaxdFRQjWnqy9H2wARxUF1ypelW	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1776614810/bahibo/profile-avatars/261324965862-avatar-1776614807121?_a=BAMAOGfk0	\N	CUSTOMER	t	2026-04-19 16:06:11.822	2026-04-26 09:55:55.15	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1776614839/bahibo/profile-covers/261324965862-cover-1776614835768?_a=BAMAOGfk0	Mountain View, Santa Clara County	37.4219983	-122.084	2026-04-26 09:52:36.347	\N	NONE	\N	\N	f	NONE	\N	\N	2026-04-26 09:55:55.148
fc758d78-e3c2-4ea7-a489-8e2886635f13	+261349459128	DAMA Dany	$2a$10$fKFR4W0i0bj5BvjKD70bfOdMKQkRJWMeaV3bygzo28vAf./vX9552	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1775204355/bahibo/profile-avatars/261349459128-avatar-1775204348725?_a=BAMAOGfk0	\N	ADMIN	t	2026-04-02 20:28:04.151	2026-04-26 14:58:16.117	+261	Madagascar	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_900,q_auto:good,w_1600/v1775203723/bahibo/profile-covers/261349459128-cover-1775203712268?_a=BAMAOGfk0	Mountain View, Santa Clara County	37.4219983	-122.084	2026-04-26 14:55:50.806	\N	NONE	\N	\N	f	NONE	\N	\N	2026-04-26 14:58:16.113
9b3b238f-3e67-4073-9b6b-afbd3731f195	+261340258202	Fifih	$2a$10$VpQoX0HdGkG0Nflczvffh.o/zm01JGPnL/VhrzDkdiGvZ3qfaxGsW	https://res.cloudinary.com/dedzvlmsf/image/upload/c_fill,f_auto,g_auto,h_512,q_auto:good,w_512/v1777197054/bahibo/profile-avatars/261340258202-avatar-1777197047033?_a=BAMAOGfk0	\N	CUSTOMER	t	2026-04-26 09:50:54.166	2026-04-26 09:54:41.722	+261	Madagascar	\N	Tananarive, Antananarivo Renivohitra	-18.9399558	47.5298438	2026-04-26 09:51:14.715	\N	NONE	\N	\N	f	NONE	\N	\N	2026-04-26 09:54:41.718
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
53a25056-caa3-4910-89de-8d7c18428606	b718efee-173e-441b-98f3-364b40c05e73	fibUwjDXQbq7LAcaQdVLFB:APA91bHSIR2q33bWImL-UoMKkDZK7VVpFv0Ltt7UBVJKqrmnkv7418Ur9RavxQNhND2Koh5zMM984Oug1u1irmyEwNev3yXWpLExMYR3_SsjPdkB8iOjYyI	android	2026-04-28 20:47:13.161	2026-04-28 20:47:13.161	2026-04-28 20:47:13.161
716adc98-e6a1-4026-9b86-4f34b6531fd9	f7fc4466-6951-4dd5-9e5b-fcbc6baf393d	dhpfAwxqRqKeA_0Ir0Q9hL:APA91bE5XyVRShExhnDJN0QPBr3C7IVlc0whqtI815KfZxyLkIaLYQWIddU4ClrtfY1f8-7IRpMcMWfQY4OvfbJHHxKTG4_TDhFwouHyzVmhyLM7XHNgJk4	android	2026-04-07 15:13:13.9	2026-04-26 09:48:36.737	2026-04-26 09:48:36.734
acc4d6d8-369f-454b-9201-2e1fed7c6a4c	9b3b238f-3e67-4073-9b6b-afbd3731f195	dMwGGt4OSM-HhHGf8ZbzHx:APA91bGwlcZ3IQYj0hRpyxZl4jg_MxGu1PFzVsCHz4mU9JyfQtv7R8EI7zWehvwxbaiPuVhKGp-hNGG0jGEDl0VXXARprtn1pjQCfhPVJhnWN2tWAj0yYLE	android	2026-04-26 09:50:54.478	2026-04-26 09:50:54.478	2026-04-26 09:50:54.477
0a0ca5c0-cd3d-4f87-b202-297b94167ee1	b718efee-173e-441b-98f3-364b40c05e73	fTcVOqgoQlCWDkJB1VeRCd:APA91bGRaA7wrbaCK3buaHHED0wRojfmYS1YtWoC8t4P7z4w36aYr_P1Cc4VexkWy6ZrjL2D3r6sEd_BJSFqLaquW0S2pBMQc5bKZHMxsyWq6kOQJ1ywh-Y	android	2026-04-13 08:18:54.022	2026-04-26 13:26:17.157	2026-04-26 13:26:17.155
a4f1e050-75d3-4639-b4fe-358ac5a3b668	fc758d78-e3c2-4ea7-a489-8e2886635f13	cMYIwqxeQD-PnQ1KtDoua_:APA91bFDZ9e2wivNAiHdXXft2BfB-GeU9DOGvSYaCgFxKOHoNmZswTx1QczWQiBtXJx0xxVbO5yTNZZl7B2vbW_KEM2MM5aQXS-8GuYUcXR01GZrP4_WgVg	android	2026-04-24 05:02:47.012	2026-04-26 13:27:18.402	2026-04-26 13:27:18.401
5072e85d-ce52-4ea2-b2a5-8c6ec370ff09	b718efee-173e-441b-98f3-364b40c05e73	ejCf0fPZT0qXqlalWxe5NQ:APA91bEfpXrP09TGOA0Q_s5cfG0zPjL0dDo--JViJFRlRMFT9-njczVS0LCcAO9Ve63Q_uUmuo9bKgkb_moODxayBguuRvYN-2b1UVjbkoMNEMCdTCyIrSM	android	2026-04-26 14:00:43.446	2026-04-27 17:06:11.844	2026-04-27 17:06:11.842
d75c5c80-0348-457a-8568-d46a7d63971c	b718efee-173e-441b-98f3-364b40c05e73	egEchG87TjybJD5bgcLVHK:APA91bFPZnf2Tza28KpFLp8yOb1Hwxn-e2U6mBDBxxr_CksQC2xUT_cMSnJ4FU5uVbrSx8YUHyzNFNMt4Jw6VvrSYkOVgfZibJmZvNME2s5loIHCsxkUsgg	android	2026-04-27 17:07:23.821	2026-04-27 17:07:23.821	2026-04-27 17:07:23.82
ea4dd1ea-c218-4faa-b5f7-29a24f12cff8	fc758d78-e3c2-4ea7-a489-8e2886635f13	dRRHEs38Sfe8LeHPNNFpkI:APA91bG9oEYBb-FURBGANOWFB3dCA8PbEiD1jlOXWk0-9ITzXqEe9HwimT599KR4nca0N4JNtHUNSCGomChIvsp3S_Ck4-NTtQAYuUEom1n1cQ0FHV1Pm54	android	2026-04-03 00:19:30.642	2026-04-27 17:13:40.899	2026-04-27 17:13:40.898
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
-- Name: ChatMessage_conversationId_createdAt_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_conversationId_createdAt_idx" ON public."ChatMessage" USING btree ("conversationId", "createdAt");


--
-- Name: ChatMessage_productId_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "ChatMessage_productId_idx" ON public."ChatMessage" USING btree ("productId");


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

\unrestrict dsOUp8dCNFUP4yA5gzc2vGyzw2jR7nDGDHYal1QAMob6QZTMwtVCZRO4If9XvRc

