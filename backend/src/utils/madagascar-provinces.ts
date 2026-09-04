import { computeDistanceInKm } from './geo';

/**
 * The six historical provinces (faritany) of Madagascar, with their capital
 * used as an anchor for the nearest-capital fallback.
 */
const PROVINCES = [
  { name: 'Antananarivo', latitude: -18.9137, longitude: 47.5361 },
  { name: 'Antsiranana', latitude: -12.352, longitude: 49.2968 },
  { name: 'Fianarantsoa', latitude: -21.4527, longitude: 47.0863 },
  { name: 'Mahajanga', latitude: -15.7162, longitude: 46.32 },
  { name: 'Toamasina', latitude: -18.1492, longitude: 49.4023 },
  { name: 'Toliara', latitude: -23.3533, longitude: 43.683 },
] as const;

type ProvinceName = (typeof PROVINCES)[number]['name'];

/**
 * Keywords (regions, districts, cities, French / Malagasy aliases) that pin a
 * label to a province, matched case- and accent-insensitively. Checked before
 * the coordinate fallback because province borders do not follow distance to
 * the capital (Moramanga is closer to Antananarivo than to Toamasina).
 */
const KEYWORDS: Record<ProvinceName, readonly string[]> = {
  Antananarivo: [
    'antananarivo', 'tananarive', 'tana', 'analamanga', 'bongolava', 'itasy',
    'vakinankaratra', 'antsirabe', 'ambatolampy', 'tsiroanomandidy', 'miarinarivo',
    'ambohidratrimo', 'manjakandriana', 'anjozorobe', 'ankazobe', 'arivonimamo',
    'soavinandriana', 'andramasina', 'betafo', 'faratsiho', 'ambatofinandrahana',
  ],
  Antsiranana: [
    'antsiranana', 'diego', 'diana', 'sava', 'nosy be', 'nosy-be', 'ambilobe',
    'ambanja', 'sambava', 'antalaha', 'vohemar', 'andapa',
  ],
  Fianarantsoa: [
    'fianarantsoa', 'fianar', 'haute matsiatra', 'matsiatra', 'amoron', 'ihorombe',
    'vatovavy', 'fitovinany', 'atsimo-atsinanana', 'atsimo atsinanana', 'ambositra',
    'manakara', 'mananjary', 'farafangana', 'ihosy', 'ambalavao', 'ikalamavony',
    'vohipeno', 'nosy varika', 'ifanadiana', 'vangaindrano', 'midongy',
  ],
  Mahajanga: [
    'mahajanga', 'majunga', 'boeny', 'betsiboka', 'melaky', 'sofia', 'antsohihy',
    'maevatanana', 'maintirano', 'marovoay', 'ambato boeny', 'ambato-boeny',
    'mitsinjo', 'soalala', 'bealanana', 'befandriana', 'mandritsara', 'port-berge',
    'port berge', 'boriziny', 'analalava', 'mampikony', 'kandreho', 'tsaratanana',
    'besalampy', 'morafenobe', 'antsalova', 'ambatomainty',
  ],
  Toamasina: [
    'toamasina', 'tamatave', 'atsinanana', 'analanjirofo', 'alaotra', 'mangoro',
    'moramanga', 'ambatondrazaka', 'fenoarivo', 'fenerive', 'sainte-marie',
    'sainte marie', 'nosy boraha', 'maroantsetra', 'mananara', 'vavatenina',
    'soanierana', 'brickaville', 'vatomandry', 'mahanoro', 'marolambo',
    'andilamena', 'amparafaravola', 'anosibe',
  ],
  Toliara: [
    'toliara', 'toliary', 'tulear', 'atsimo-andrefana', 'atsimo andrefana',
    'androy', 'anosy', 'menabe', 'morondava', 'fort-dauphin', 'fort dauphin',
    'taolagnaro', 'tolagnaro', 'ambovombe', 'betioky', 'ampanihy', 'sakaraha',
    'benenitra', 'ankazoabo', 'morombe', 'beroroha', 'belo sur', 'mahabo',
    'miandrivazo', 'manja', 'bekily', 'beloha', 'tsihombe', 'amboasary', 'betroka',
  ],
};

/** Beyond this distance from every capital the point is not in Madagascar. */
const MAX_PROVINCE_ANCHOR_DISTANCE_KM = 450;

/** Lower-cases, strips accents and reduces punctuation to single spaces. */
function normalize(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z]+/g, ' ')
    .trim();
}

/**
 * Flat keyword list, longest first, so "Antananarivo Atsimondrano" wins over
 * "tana" and a short alias never matches inside a longer, unrelated name
 * ("Antanambao" must not resolve to Antananarivo).
 */
const KEYWORD_ENTRIES: ReadonlyArray<{ keyword: string; province: ProvinceName }> = (
  Object.entries(KEYWORDS) as Array<[ProvinceName, readonly string[]]>
)
  .flatMap(([province, keywords]) =>
    keywords.map((keyword) => ({ keyword: normalize(keyword), province })),
  )
  .sort((first, second) => second.keyword.length - first.keyword.length);

/**
 * Resolves the Madagascar province a user location belongs to, or null when
 * the label carries no known place name and the coordinates are outside the
 * island. Label keywords win over coordinates; coordinates are only a
 * nearest-capital approximation.
 */
export function resolveMadagascarProvince(params: {
  locationLabel?: string | null;
  latitude?: number | null;
  longitude?: number | null;
}): string | null {
  const label = params.locationLabel?.trim();
  if (label) {
    // Whole-word match: pad with spaces so "tana" only matches the word "tana".
    const paddedLabel = ` ${normalize(label)} `;
    const hit = KEYWORD_ENTRIES.find((entry) => paddedLabel.includes(` ${entry.keyword} `));
    if (hit) {
      return hit.province;
    }
  }

  const { latitude, longitude } = params;
  if (latitude == null || longitude == null) {
    return null;
  }

  let nearest: string | null = null;
  let nearestDistanceKm = MAX_PROVINCE_ANCHOR_DISTANCE_KM;
  for (const province of PROVINCES) {
    const distanceKm = computeDistanceInKm(
      latitude,
      longitude,
      province.latitude,
      province.longitude,
    );
    if (distanceKm < nearestDistanceKm) {
      nearestDistanceKm = distanceKm;
      nearest = province.name;
    }
  }

  return nearest;
}
