import { createBrowserRouter } from 'react-router-dom';
import BasicLayout from '../layouts/BasicLayout';
import Login from '../pages/Login';
import Dashboard from '../pages/Dashboard';
import UserManage from '../pages/UserManage';
import ContentAudit from '../pages/ContentAudit';
import Financial from '../pages/Financial';

const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
  },
  {
    path: '/',
    element: <BasicLayout />,
    children: [
      {
        path: '',
        element: <Dashboard />,
      },
      {
        path: 'users',
        element: <UserManage />,
      },
      {
        path: 'content-audit',
        element: <ContentAudit />,
      },
      {
        path: 'finance',
        element: <Financial />,
      },
    ],
  },
]);

export default router;
