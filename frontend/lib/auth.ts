import api from './api';
import Cookies from 'js-cookie';

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  client_id?: number;
}

export interface AuthResponse {
  token: string;
  user: User;
}

export const authService = {
  async login(credentials: LoginCredentials): Promise<AuthResponse> {
    try {
      console.log('Attempting login to:', api.defaults.baseURL + '/auth/login');
      const response = await api.post<AuthResponse>('/auth/login', credentials);
      if (response.data && response.data.token) {
        Cookies.set('auth_token', response.data.token, { expires: 7 });
        return response.data;
      } else {
        throw new Error('Токен не получен от сервера');
      }
    } catch (error: any) {
      console.error('Auth service error:', error);
      // Более детальная обработка ошибок
      if (!error.response) {
        // Network error - бэкенд недоступен
        throw new Error(`Не удалось подключиться к серверу. Проверьте, что бэкенд запущен на ${api.defaults.baseURL}`);
      }
      throw error;
    }
  },

  async register(data: { name: string; email: string; password: string }): Promise<AuthResponse> {
    try {
      // Сначала регистрируем пользователя
      const registerResponse = await api.post('/auth/register', data);
      
      if (!registerResponse.data || !registerResponse.data.success) {
        throw new Error('Ошибка регистрации');
      }

      // После успешной регистрации автоматически входим
      const loginResponse = await api.post<AuthResponse>('/auth/login', {
        email: data.email,
        password: data.password,
      });

      if (loginResponse.data && loginResponse.data.token) {
        Cookies.set('auth_token', loginResponse.data.token, { expires: 7 });
        return loginResponse.data;
      } else {
        throw new Error('Токен не получен после регистрации');
      }
    } catch (error: any) {
      console.error('Register service error:', error);
      throw error;
    }
  },

  logout(): void {
    Cookies.remove('auth_token');
    window.location.href = '/login';
  },

  getToken(): string | undefined {
    return Cookies.get('auth_token');
  },

  isAuthenticated(): boolean {
    return !!Cookies.get('auth_token');
  },
};

