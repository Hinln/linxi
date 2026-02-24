import React, { useState } from 'react';
import { Layout, Menu, Avatar, Dropdown } from 'antd';
import {
  DesktopOutlined,
  UserOutlined,
  AuditOutlined,
  PayCircleOutlined,
  LogoutOutlined,
} from '@ant-design/icons';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';

const { Header, Content, Footer, Sider } = Layout;

type MenuItem = {
  key: string;
  icon?: React.ReactNode;
  label: string;
  path?: string;
};

const items: MenuItem[] = [
  { key: 'dashboard', icon: <DesktopOutlined />, label: 'Dashboard', path: '/' },
  { key: 'users', icon: <UserOutlined />, label: 'User Management', path: '/users' },
  { key: 'content', icon: <AuditOutlined />, label: 'Content Audit', path: '/content-audit' },
  { key: 'finance', icon: <PayCircleOutlined />, label: 'Financial', path: '/finance' },
];

const BasicLayout: React.FC = () => {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  const handleMenuClick = (e: { key: string }) => {
    const item = items.find((i) => i.key === e.key);
    if (item?.path) {
      navigate(item.path);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    navigate('/login');
  };

  const userMenuItems = [
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Logout',
      onClick: handleLogout,
    },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed}>
        <div className="h-16 flex items-center justify-center text-white text-xl font-bold bg-gray-800">
          LinXi Admin
        </div>
        <Menu
          theme="dark"
          defaultSelectedKeys={[location.pathname === '/' ? 'dashboard' : location.pathname.substring(1)]}
          mode="inline"
          items={items}
          onClick={handleMenuClick}
        />
      </Sider>
      <Layout className="site-layout">
        <Header className="site-layout-background p-0 bg-white flex justify-end items-center px-4 shadow">
          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
            <div className="cursor-pointer flex items-center gap-2">
              <Avatar icon={<UserOutlined />} />
              <span>Admin</span>
            </div>
          </Dropdown>
        </Header>
        <Content style={{ margin: '16px' }}>
          <div className="p-6 min-h-[360px] bg-white rounded-lg shadow-sm">
            <Outlet />
          </div>
        </Content>
        <Footer style={{ textAlign: 'center' }}>LinXi Admin ©2026 Created by Trae AI</Footer>
      </Layout>
    </Layout>
  );
};

export default BasicLayout;
