'use client';

import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import api from '@/lib/api';
import { User } from '@/lib/types';
import styles from './Navigation.module.scss';

export default function Navigation() {
  const pathname = usePathname();
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    // Не загружаем пользователя на страницах логина и регистрации
    if (pathname === '/login' || pathname === '/register') {
      return;
    }
    loadUser();
  }, [pathname]);

  const loadUser = async () => {
    try {
      const res = await api.get('/auth/me');
      setUser(res.data);
    } catch (error) {
      // Не авторизован - игнорируем ошибку
      setUser(null);
    }
  };

  // Не показываем навигацию на странице входа, регистрации и админ-панели
  // (админ-панель имеет свой собственный header)
  if (pathname === '/login' || pathname === '/register' || pathname === '/admin') {
    return null;
  }

  const isAdmin = user?.role === 'admin';

  return (
    <header className={styles.header}>
      <div className="container">
        <h1 className={styles.title}>Панель управления</h1>
        <nav className={styles.nav}>
          <Link 
            href="/dashboard" 
            className={pathname === '/dashboard' ? styles.active : ''}
          >
            Дашборд
          </Link>
          <Link 
            href="/requirements" 
            className={pathname === '/requirements' ? styles.active : ''}
          >
            Требования
          </Link>
          <Link 
            href="/documents" 
            className={pathname === '/documents' ? styles.active : ''}
          >
            Документы
          </Link>
          <Link 
            href="/calendar" 
            className={pathname === '/calendar' ? styles.active : ''}
          >
            Календарь
          </Link>
          <Link 
            href="/contracts" 
            className={pathname === '/contracts' ? styles.active : ''}
          >
            Договоры
          </Link>
          {isAdmin && (
            <Link 
              href="/admin" 
              className={pathname === '/admin' ? styles.active : ''}
            >
              Админ панель
            </Link>
          )}
          {user && (
            <button
              onClick={() => {
                // Удаляем токен
                if (typeof window !== 'undefined') {
                  const Cookies = require('js-cookie');
                  Cookies.remove('auth_token');
                }
                // Перенаправляем на страницу входа
                window.location.href = '/login';
              }}
              className={styles.logoutButton}
            >
              Выйти
            </button>
          )}
        </nav>
      </div>
    </header>
  );
}

