import request from '../utils/request';

export const login = (data: { phoneNumber: string; verificationCode: string }) => {
  return request.post('/auth/login', data);
};

export const sendCode = (phoneNumber: string) => {
  return request.post('/auth/send-code', { phoneNumber });
};
