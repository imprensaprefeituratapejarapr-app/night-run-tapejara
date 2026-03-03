// =============================================
// SUPABASE CLIENT CONFIG
// =============================================
const SUPABASE_URL = 'https://agkvkcpaaaimwhhopfpl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFna3ZrY3BhYWFpbXdoaG9wZnBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NDUxOTIsImV4cCI6MjA4ODEyMTE5Mn0.pFx-f5M1-KXlK0DcTXNtqX-P60ynFHD3ITbr6ypxWlw';

// IMPORTANT: named supabaseClient to avoid conflict with window.supabase (CDN global)
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// =============================================
// AUTH HELPERS
// =============================================

async function getSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    return session;
}

async function getProfile(userId) {
    const { data, error } = await supabaseClient
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();
    if (error) throw error;
    return data;
}

async function getRegistration(userId) {
    const { data, error } = await supabaseClient
        .from('registrations')
        .select('*')
        .eq('user_id', userId)
        .single();
    if (error && error.code !== 'PGRST116') throw error;
    return data;
}

async function logout() {
    await supabaseClient.auth.signOut();
    window.location.href = 'login.html';
}

// Auth guard: redirect to login if not authenticated
async function requireAuth() {
    const session = await getSession();
    if (!session) {
        window.location.href = 'login.html';
        return null;
    }
    return session;
}

// Admin guard: redirect if not admin
async function requireAdmin() {
    const session = await requireAuth();
    if (!session) return null;
    const profile = await getProfile(session.user.id);
    if (profile.role !== 'admin') {
        window.location.href = 'painel-atleta.html';
        return null;
    }
    return { session, profile };
}

// Format date BR
function formatDateBR(dateStr) {
    if (!dateStr) return '—';
    const d = new Date(dateStr);
    return d.toLocaleDateString('pt-BR');
}

// Format currency BR  
function formatCurrency(value) {
    return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value || 0);
}

// Status badge colors
function getStatusInfo(status) {
    const map = {
        'pending_payment': { label: 'Pagamento Pendente', color: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20', icon: 'schedule' },
        'awaiting_approval': { label: 'Aguardando Aprovação', color: 'bg-blue-500/10 text-blue-400 border-blue-500/20', icon: 'hourglass_top' },
        'confirmed': { label: 'Confirmada', color: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20', icon: 'check_circle' },
        'rejected': { label: 'Rejeitada', color: 'bg-red-500/10 text-red-400 border-red-500/20', icon: 'cancel' },
        'cancelled': { label: 'Cancelada', color: 'bg-slate-500/10 text-slate-400 border-slate-500/20', icon: 'block' }
    };
    return map[status] || map['pending_payment'];
}

// Calculate age from birth_date
function calculateAge(birthDate) {
    if (!birthDate) return '—';
    const today = new Date();
    const birth = new Date(birthDate);
    let age = today.getFullYear() - birth.getFullYear();
    const m = today.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
    return age;
}

// CPF mask
function maskCPF(input) {
    let v = input.value.replace(/\D/g, '');
    v = v.replace(/(\d{3})(\d)/, '$1.$2');
    v = v.replace(/(\d{3})(\d)/, '$1.$2');
    v = v.replace(/(\d{3})(\d{1,2})$/, '$1-$2');
    input.value = v;
}

// Phone mask
function maskPhone(input) {
    let v = input.value.replace(/\D/g, '');
    v = v.replace(/^(\d{2})(\d)/g, '($1) $2');
    v = v.replace(/(\d{5})(\d)/, '$1-$2');
    input.value = v;
}

// Toast notification
function showToast(message, type = 'success') {
    const colors = {
        success: 'bg-emerald-600',
        error: 'bg-red-600',
        warning: 'bg-yellow-600',
        info: 'bg-blue-600'
    };
    const toast = document.createElement('div');
    toast.className = `fixed top-6 right-6 z-[9999] px-6 py-4 rounded-2xl ${colors[type]} text-white font-semibold shadow-2xl transform transition-all duration-500 translate-x-full opacity-0`;
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(() => {
        toast.classList.remove('translate-x-full', 'opacity-0');
        toast.classList.add('translate-x-0', 'opacity-100');
    });
    setTimeout(() => {
        toast.classList.remove('translate-x-0', 'opacity-100');
        toast.classList.add('translate-x-full', 'opacity-0');
        setTimeout(() => toast.remove(), 500);
    }, 4000);
}
