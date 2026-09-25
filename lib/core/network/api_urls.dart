class ApiUrls {
  // ── Auth ────────────────────────────────────────────────────────────────
  static const String volunteerLogin = '/api/v1/auth/volunteer/login';
  static const String workerLogin = '/api/v1/auth/worker/login';
  static const String authMe = '/api/v1/auth/me';

  // ── Field sync / workers / tasks ────────────────────────────────────────
  static const String fieldSync = '/api/v1/field/sync';
  static const String workers = '/api/v1/workers';
  static String workerById(String id) => '/api/v1/workers/$id';
  static String workerPlots(String id) => '/api/v1/workers/$id/plots';
  static const String treeTasks = '/api/v1/tree-tasks';
  static String treeTaskById(String id) => '/api/v1/tree-tasks/$id';
  static String treeGrowth(String treeId) => '/api/v1/trees/$treeId/growth';

  // ── Plots ───────────────────────────────────────────────────────────────
  static const String plots = '/api/v1/plots';
  static String plotById(String id) => '/api/v1/plots/$id';
  static const String fieldPlots = '/api/v1/field/plots';
  static String fieldPlotById(String id) => '/api/v1/field/plots/$id';

  // ── Volunteer summary ───────────────────────────────────────────────────
  static const String volunteerSummary = '/api/v1/volunteers/me/summary';
}
