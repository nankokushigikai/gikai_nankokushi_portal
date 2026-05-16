window.AUTH_CONFIG = {
    supabaseUrl: "https://gnnfzimhfizbfhvwuzbf.supabase.co",
    supabaseAnonKey: "sb_publishable__SRHapM6Zzz01tC--VG9YQ_-xN3re0Q",
    googleEnabled: true,
    authPaused: false,
    // 政務活動費アプリの本番公開URL（末尾スラッシュ不要）。
    // 例: "https://seimu.example.com"
    seimukatudouhiAppBaseUrl: "",
    // Google Cloud Console で発行した OAuth 2.0 Client ID を設定
    googleClientId: "995727635041-4btvd387rc69h0agjq4ld4ko9jlmpuki.apps.googleusercontent.com",
    // 本番公開向けの最小スコープ
    googleScopes: [
        "openid",
        "email",
        "profile"
    ]
};

window.ROLE_ORDER = {
    viewer: 1,
    editor: 2,
    admin: 3
};

window.DEFAULT_RETURN_PATH = "index.html";
