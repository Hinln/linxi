// Generic API Response
export interface ApiResponse<T = any> {
  statusCode: number;
  message: string;
  data: T;
}

// User Info
export interface User {
  id: number;
  phone: string;
  nickname: string;
  avatarUrl: string;
  verifyStatus: 'UNVERIFIED' | 'PENDING' | 'VERIFIED';
  goldBalance: string; // Decimal as string to preserve precision
  role: 'USER' | 'ADMIN';
  status: 'NORMAL' | 'BANNED';
  createdAt: string;
}

// Report
export interface Report {
  id: number;
  reporterId: number;
  contentType: 'POST' | 'USER' | 'COMMENT';
  contentId: number;
  reason: string;
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED';
  createdAt: string;
  reporter: {
    id: number;
    nickname: string;
    phone: string;
  };
  contentDetails?: any; // Dynamic content
}

// Pagination
export interface PaginationParams {
  limit?: number;
  offset?: number;
}
