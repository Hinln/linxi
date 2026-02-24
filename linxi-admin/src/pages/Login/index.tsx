import React, { useState } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import { LockOutlined, MobileOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import * as AuthApi from '../../api/auth';

const Login: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const { phoneNumber, verificationCode } = values;
      const res: any = await AuthApi.login({ phoneNumber, verificationCode });
      
      if (res.accessToken) {
        localStorage.setItem('token', res.accessToken);
        localStorage.setItem('user', JSON.stringify(res.user));
        
        if (res.user.role === 'ADMIN') {
           message.success('Login successful');
           navigate('/');
        } else {
           message.error('Access denied: Admins only');
           localStorage.clear();
        }
      } else {
        message.error('Login failed');
      }
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleSendCode = async () => {
    // In real app, get phone from form instance
    message.info('Please enter phone number and check console for code (Dev Mode)');
    // AuthApi.sendCode(...)
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <Card title="LinXi Admin Console" className="w-96 shadow-lg">
        <Form
          name="login"
          initialValues={{ remember: true }}
          onFinish={onFinish}
          layout="vertical"
        >
          <Form.Item
            name="phoneNumber"
            rules={[{ required: true, message: 'Please input your Phone Number!' }]}
          >
            <Input prefix={<MobileOutlined />} placeholder="Phone Number" />
          </Form.Item>

          <Form.Item
            name="verificationCode"
            rules={[{ required: true, message: 'Please input Verification Code!' }]}
          >
            <div className="flex gap-2">
              <Input prefix={<LockOutlined />} placeholder="Verification Code" />
              <Button onClick={handleSendCode}>Send</Button>
            </div>
          </Form.Item>

          <Form.Item>
            <Button type="primary" htmlType="submit" className="w-full" loading={loading}>
              Log in
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default Login;
