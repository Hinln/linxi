import request from '../utils/request';

export const getReports = (params: any) => {
  return request.get('/admin/reports', { params });
};

export const processReport = (id: number, data: { accepted: boolean; details?: string }) => {
  return request.patch(`/admin/reports/${id}/process`, data);
};

export const updateUserStatus = (userId: number, status: 'NORMAL' | 'BANNED') => {
  return request.patch(`/admin/users/${userId}/status`, { status });
};
