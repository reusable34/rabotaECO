'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import api from '@/lib/api';
import { Client, Requirement, Event } from '@/lib/types';
import styles from './dashboard.module.scss';

export default function DashboardPage() {
  const router = useRouter();
  const [client, setClient] = useState<Client | null>(null);
  const [requirements, setRequirements] = useState<Requirement[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [clientRes, requirementsRes, eventsRes] = await Promise.all([
        api.get('/client'),
        api.get('/requirement'),
        api.get('/event'),
      ]);

      // Yii2 REST может возвращать данные в разных форматах
      // Проверяем оба варианта: массив напрямую или объект с items
      const clients = Array.isArray(clientRes.data) ? clientRes.data : (clientRes.data?.items || []);
      const requirements = Array.isArray(requirementsRes.data) ? requirementsRes.data : (requirementsRes.data?.items || []);
      const events = Array.isArray(eventsRes.data) ? eventsRes.data : (eventsRes.data?.items || []);

      if (clients.length > 0) {
        setClient(clients[0]);
      }

      setRequirements(requirements);
      setEvents(events);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  const pendingRequirements = requirements.filter((r) => r.status === 'pending').length;
  const upcomingEvents = events.filter((e) => !e.completed && new Date(e.date) >= new Date()).slice(0, 5);

  return (
    <div className={styles.dashboard}>
      <main className={styles.content}>
        <div className={styles.stats}>
          <div className={styles.statCard}>
            <h3>Всего требований</h3>
            <p className={styles.statNumber}>{requirements.length}</p>
          </div>
          <div className={styles.statCard}>
            <h3>В ожидании</h3>
            <p className={styles.statNumber}>{pendingRequirements}</p>
          </div>
          <div className={styles.statCard}>
            <h3>Ближайшие события</h3>
            <p className={styles.statNumber}>{upcomingEvents.length}</p>
          </div>
        </div>

        <div className={styles.grid}>
          <div className={styles.card}>
            <h2>Требования</h2>
            <div className={styles.requirementsList}>
              {requirements.slice(0, 5).map((req) => (
                <div key={req.id} className={styles.requirementItem}>
                  <span className={styles.requirementTitle}>{req.title}</span>
                  <span className={`status-badge status-${req.status}`}>
                    {req.status === 'pending' && 'Ожидание'}
                    {req.status === 'in_progress' && 'В работе'}
                    {req.status === 'completed' && 'Выполнено'}
                    {req.status === 'not_completed' && 'Не выполнено'}
                  </span>
                </div>
              ))}
            </div>
            <Link href="/requirements" className={styles.viewAll}>
              Посмотреть все →
            </Link>
          </div>

          <div className={styles.card}>
            <h2>Ближайшие события</h2>
            <div className={styles.eventsList}>
              {upcomingEvents.length > 0 ? (
                upcomingEvents.map((event) => (
                  <div key={event.id} className={styles.eventItem}>
                    <span className={styles.eventDate}>
                      {new Date(event.date).toLocaleDateString('ru-RU')}
                    </span>
                    <span className={styles.eventTitle}>{event.title}</span>
                  </div>
                ))
              ) : (
                <p className={styles.empty}>Нет предстоящих событий</p>
              )}
            </div>
            <Link href="/calendar" className={styles.viewAll}>
              Открыть календарь →
            </Link>
          </div>
        </div>
      </main>
    </div>
  );
}

