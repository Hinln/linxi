import React, { useState, useEffect } from 'react';
import { Table, Button, Modal, Tag, Space, Image, message, Input } from 'antd';
import type { ColumnsType } from 'antd/es/table';
import dayjs from 'dayjs';
import { getReports, processReport, updateUserStatus } from '../../api/admin';
import { Report } from '../../types/api';

const { TextArea } = Input;

const ContentAudit: React.FC = () => {
  const [data, setData] = useState<Report[]>([]);
  const [loading, setLoading] = useState(false);
  const [pagination, setPagination] = useState({ current: 1, pageSize: 10, total: 0 });
  const [modalVisible, setModalVisible] = useState(false);
  const [currentReport, setCurrentReport] = useState<Report | null>(null);
  const [processLoading, setProcessLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState('');

  const fetchData = async (page = 1, pageSize = 10) => {
    setLoading(true);
    try {
      const res: any = await getReports({
        limit: pageSize,
        offset: (page - 1) * pageSize,
      });
      // Assuming backend returns array or { data: [], total: number }
      // The current backend implementation returns array directly, without total count for now.
      // We might need to adjust backend or assume infinite scroll.
      // For now, let's just set data. If backend returns array, use it.
      if (Array.isArray(res)) {
        setData(res);
        setPagination({ ...pagination, current: page, pageSize, total: 100 }); // Mock total
      } else if (res.data) {
        setData(res.data);
        setPagination({ ...pagination, current: page, pageSize, total: res.total || 100 });
      }
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleProcess = async (accepted: boolean) => {
    if (!currentReport) return;
    setProcessLoading(true);
    try {
      await processReport(currentReport.id, {
        accepted,
        details: accepted ? 'Admin accepted via console' : rejectReason,
      });
      message.success(accepted ? 'Report accepted' : 'Report rejected');
      setModalVisible(false);
      fetchData(pagination.current, pagination.pageSize);
    } catch (error) {
      console.error(error);
    } finally {
      setProcessLoading(false);
    }
  };

  const handleBanUser = async (userId: number) => {
    try {
      await updateUserStatus(userId, 'BANNED');
      message.success('User banned successfully');
      fetchData(pagination.current, pagination.pageSize);
    } catch (error) {
      console.error(error);
    }
  };

  const columns: ColumnsType<Report> = [
    {
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      title: 'Type',
      dataIndex: 'contentType',
      render: (type) => <Tag color={type === 'POST' ? 'blue' : 'green'}>{type}</Tag>,
    },
    {
      title: 'Reporter',
      dataIndex: ['reporter', 'nickname'],
    },
    {
      title: 'Reason',
      dataIndex: 'reason',
    },
    {
      title: 'Time',
      dataIndex: 'createdAt',
      render: (text) => dayjs(text).format('YYYY-MM-DD HH:mm'),
    },
    {
      title: 'Status',
      dataIndex: 'status',
      render: (status) => {
        const color = status === 'PENDING' ? 'gold' : status === 'ACCEPTED' ? 'green' : 'red';
        return <Tag color={color}>{status}</Tag>;
      },
    },
    {
      title: 'Action',
      key: 'action',
      render: (_, record) => (
        <Space size="middle">
          <Button type="link" onClick={() => { setCurrentReport(record); setModalVisible(true); }}>
            View Details
          </Button>
          {record.status === 'PENDING' && (
            <Button danger type="text" onClick={() => { setCurrentReport(record); setModalVisible(true); }}>
              Audit
            </Button>
          )}
        </Space>
      ),
    },
  ];

  const renderContentDetails = (report: Report) => {
    if (!report.contentDetails) return <p>No details available</p>;
    
    if (report.contentType === 'POST') {
      const post = report.contentDetails;
      return (
        <div className="space-y-4">
          <div className="p-4 bg-gray-50 rounded">
            <p className="font-semibold mb-2">Post Content:</p>
            <p>{post.content}</p>
          </div>
          {post.media && (
            <div className="grid grid-cols-3 gap-2">
              {/* Parse JSON media if needed */}
              {/* Assuming media is array of URLs string or parsed JSON */}
              {/* For demo, just placeholder */}
              <div className="h-24 bg-gray-200 flex items-center justify-center text-gray-500 rounded">
                [Media Placeholder]
              </div>
            </div>
          )}
        </div>
      );
    } else if (report.contentType === 'USER') {
      const user = report.contentDetails;
      return (
        <div className="flex items-center gap-4 p-4 bg-gray-50 rounded">
          <Image src={user.avatarUrl} width={64} className="rounded-full" />
          <div>
            <p className="font-bold">{user.nickname}</p>
            <p>Status: <Tag color={user.status === 'BANNED' ? 'red' : 'green'}>{user.status}</Tag></p>
            {user.status !== 'BANNED' && (
              <Button danger size="small" onClick={() => handleBanUser(user.id)}>
                Ban User
              </Button>
            )}
          </div>
        </div>
      );
    }
    return null;
  };

  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Content Audit</h2>
      <Table
        columns={columns}
        dataSource={data}
        rowKey="id"
        pagination={{
          ...pagination,
          onChange: (page, pageSize) => fetchData(page, pageSize),
        }}
        loading={loading}
      />

      <Modal
        title="Audit Report"
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={[
          <Button key="back" onClick={() => setModalVisible(false)}>
            Cancel
          </Button>,
          <Button 
            key="reject" 
            danger 
            onClick={() => handleProcess(false)}
            loading={processLoading}
            disabled={currentReport?.status !== 'PENDING'}
          >
            Reject Report
          </Button>,
          <Button
            key="accept"
            type="primary"
            onClick={() => handleProcess(true)}
            loading={processLoading}
            disabled={currentReport?.status !== 'PENDING'}
          >
            Accept (Delete/Ban)
          </Button>,
        ]}
        width={600}
      >
        {currentReport && (
          <div className="space-y-4">
            <div>
              <span className="font-bold">Report Reason: </span>
              {currentReport.reason}
            </div>
            <div className="border-t pt-4">
              <h4 className="font-bold mb-2">Reported Content:</h4>
              {renderContentDetails(currentReport)}
            </div>
            {currentReport.status === 'PENDING' && (
                <div className="pt-4">
                    <p className="mb-2">Rejection Reason (Optional):</p>
                    <TextArea 
                        rows={2} 
                        value={rejectReason} 
                        onChange={(e) => setRejectReason(e.target.value)} 
                        placeholder="Enter reason if rejecting..."
                    />
                </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
};

export default ContentAudit;
