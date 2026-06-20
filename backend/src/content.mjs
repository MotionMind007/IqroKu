export function createContentRoutes({
  db,
}) {
  async function handle(method, path) {
    if (method === 'GET' && path === '/daily-prayers') {
      const prayers = await db.getActivePrayers();
      return prayers.map(publicPrayer);
    }

    return null;
  }

  function publicPrayer(prayer) {
    return {
      id: prayer.id,
      title: prayer.title,
      category: prayer.category,
      arabic: prayer.arabic,
      latin: prayer.latin,
      meaning: prayer.meaning,
      sortOrder: Number(prayer.sortOrder ?? 0),
    };
  }

  return {
    handle,
  };
}
