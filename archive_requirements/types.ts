export interface Client {
  id: number;
  name: string;
  category_id: number;
  has_well: boolean;
  has_river: boolean;
  has_byproduct: boolean;
  responsible_person?: string;
}

export interface Requirement {
  id: number;
  client_id: number;
  title: string;
  status: 'pending' | 'in_progress' | 'completed' | 'not_completed';
  deadline: string;
  basis?: string;
  artifacts?: string[];
  document_year?: number;
  responsible_person?: string;
}

export interface Document {
  id: number;
  client_id: number;
  file_path: string;
  type: string;
  status: 'pending' | 'approved' | 'rejected';
}

export interface Contract {
  id: number;
  client_id: number;
  number: string;
  status: 'draft' | 'active' | 'completed' | 'cancelled';
  date: string;
}

export interface Event {
  id: number;
  client_id: number;
  title: string;
  date: string;
  completed: boolean;
}

export interface Risk {
  id: number;
  requirement_id: number;
  article: string;
  fine_min: number;
  fine_max: number;
}

export interface Category {
  id: number;
  title: string;
  description?: string;
}

export interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  client_id?: number;
}

export interface Npa {
  id: number;
  code: string;
  title: string;
  link?: string;
  block?: string;
}

