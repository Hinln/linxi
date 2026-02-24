import axios from 'axios';
import { message } from 'antd';

// Create Axios instance
const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/v1',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request Interceptor
request.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response Interceptor
request.interceptors.response.use(
  (response) => {
    // Some APIs might return data directly, some wrap in { data: ... }
    // NestJS default is usually just the object unless interceptor wraps it.
    // Let's assume standard response or direct data.
    return response.data;
  },
  (error) => {
    if (error.response) {
      const { status, data } = error.response;
      if (status === 401) {
        message.error('Session expired, please login again.');
        localStorage.removeItem('token');
        window.location.href = '/login';
      } else if (status === 403) {
        message.error('Access denied.');
      } else {
        message.error(data.message || 'Request failed');
      }
    } else {
      message.error('Network error');
    }
    return Promise.reject(error);
  }
);

export default request;
