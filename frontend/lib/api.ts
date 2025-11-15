import axios from 'axios';
import Cookies from 'js-cookie';

// Определяем URL API: если на продакшн сервере, используем тот же хост с портом бэкенда
const getApiUrl = () => {
  // Если задан явно через env - используем его
  if (process.env.NEXT_PUBLIC_API_URL) {
    return process.env.NEXT_PUBLIC_API_URL;
  }
  
  if (typeof window !== 'undefined') {
    // Если на продакшн сервере (не localhost), используем тот же хост с портом бэкенда
    const host = window.location.hostname;
    const currentPort = window.location.port;
    
    if (host !== 'localhost' && host !== '127.0.0.1') {
      // Продакшн: используем тот же хост, но порт бэкенда
      // Если фронтенд на порту 3384, бэкенд обычно на 8080
      const backendPort = process.env.NEXT_PUBLIC_API_PORT || '8080';
      return `http://${host}:${backendPort}`;
    }
  }
  
  // Локальная разработка
  return 'http://localhost:8080';
};

const api = axios.create({
  baseURL: getApiUrl(),
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000, // 10 секунд таймаут
});

// Добавление токена к каждому запросу
api.interceptors.request.use((config) => {
  const token = Cookies.get('auth_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Обработка ошибок авторизации
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Логируем ошибки сети для отладки
    if (!error.response) {
      console.error('Network Error:', {
        message: error.message,
        code: error.code,
        baseURL: api.defaults.baseURL,
        url: error.config?.url,
      });
    }
    
    if (error.response?.status === 401) {
      Cookies.remove('auth_token');
      // Не делаем редирект, если уже на странице логина или регистрации
      const currentPath = window.location.pathname;
      if (currentPath !== '/login' && currentPath !== '/register') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;

