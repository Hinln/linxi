import React from 'react';
import { Card, Col, Row, Statistic } from 'antd';
import { UserOutlined, PayCircleOutlined, AlertOutlined, RiseOutlined } from '@ant-design/icons';

const Dashboard: React.FC = () => {
  return (
    <div className="p-4">
      <h2 className="text-2xl font-bold mb-6">Dashboard</h2>
      <Row gutter={16}>
        <Col span={6}>
          <Card bordered={false} className="shadow-sm">
            <Statistic
              title="Total Users"
              value={112893}
              prefix={<UserOutlined />}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card bordered={false} className="shadow-sm">
            <Statistic
              title="Today's Posts"
              value={93}
              prefix={<RiseOutlined />}
              valueStyle={{ color: '#cf1322' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card bordered={false} className="shadow-sm">
            <Statistic
              title="Pending Reports"
              value={12}
              prefix={<AlertOutlined />}
              valueStyle={{ color: '#faad14' }}
            />
          </Card>
        </Col>
        <Col span={6}>
          <Card bordered={false} className="shadow-sm">
            <Statistic
              title="Today's Revenue (Coins)"
              value={2340}
              precision={2}
              prefix={<PayCircleOutlined />}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;
