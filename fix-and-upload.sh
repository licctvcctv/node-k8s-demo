#!/bin/bash
echo "修复auth.js并上传到GitHub..."

# 确保auth.js是正确的版本
cat > services/shared/auth.js << 'EOF'
// 云原生商城 - 统一认证模块（修复跨端口问题）
// 解决跨端口token共享问题

const AUTH = {
    // 统一的存储key
    TOKEN_KEY: 'cloud_shop_token',
    USER_KEY: 'cloud_shop_user',
    
    // 保存认证信息
    saveAuth(token, user) {
        localStorage.setItem(this.TOKEN_KEY, token);
        localStorage.setItem(this.USER_KEY, JSON.stringify(user));
        console.log('认证信息已保存');
    },
    
    // 获取token
    getToken() {
        return localStorage.getItem(this.TOKEN_KEY);
    },
    
    // 获取用户信息
    getUser() {
        const userStr = localStorage.getItem(this.USER_KEY);
        return userStr ? JSON.parse(userStr) : null;
    },
    
    // 清除认证信息
    clearAuth() {
        localStorage.removeItem(this.TOKEN_KEY);
        localStorage.removeItem(this.USER_KEY);
    },
    
    // 检查登录状态
    checkAuth() {
        const token = this.getToken();
        if (!token) {
            alert('请先登录');
            // 保存当前页面URL，登录后返回
            sessionStorage.setItem('redirect_after_login', window.location.href);
            window.location.href = `http://${window.location.hostname}:30081/login.html`;
            return false;
        }
        return token;
    },
    
    // 跨服务跳转（带token）- 修复版：使用URL参数
    redirectWithToken(targetUrl) {
        const token = this.getToken();
        const user = this.getUser();
        if (!token) {
            alert('请先登录');
            return;
        }
        
        // 直接在URL中传递加密的认证信息
        const authData = {
            token: token,
            user: user,
            timestamp: Date.now()
        };
        
        // 使用base64编码认证信息
        const encodedAuth = btoa(encodeURIComponent(JSON.stringify(authData)));
        
        // 跳转时带上认证信息
        const separator = targetUrl.includes('?') ? '&' : '?';
        window.location.href = `${targetUrl}${separator}auth=${encodedAuth}`;
    },
    
    // 接收跨服务传来的token - 修复版
    receiveToken() {
        const urlParams = new URLSearchParams(window.location.search);
        const encodedAuth = urlParams.get('auth');
        
        if (encodedAuth) {
            try {
                // 解码认证信息
                const authDataStr = decodeURIComponent(atob(encodedAuth));
                const authData = JSON.parse(authDataStr);
                
                // 验证时间戳（5分钟内有效）
                if (Date.now() - authData.timestamp < 5 * 60 * 1000) {
                    this.saveAuth(authData.token, authData.user);
                    console.log('跨服务认证成功');
                } else {
                    console.log('认证信息已过期');
                }
            } catch (e) {
                console.error('接收认证信息失败:', e);
            }
            
            // 清理URL中的auth参数
            const newUrl = new URL(window.location);
            newUrl.searchParams.delete('auth');
            window.history.replaceState({}, '', newUrl.toString());
        }
    },
    
    // API请求的通用headers
    getAuthHeaders() {
        const token = this.getToken();
        return {
            'Content-Type': 'application/json',
            'Authorization': token ? `Bearer ${token}` : ''
        };
    },
    
    // 处理API错误
    handleApiError(error) {
        if (error.status === 401 || error.status === 403) {
            this.clearAuth();
            alert('登录已过期，请重新登录');
            window.location.href = `http://${window.location.hostname}:30081/login.html`;
        }
    },
    
    // 创建导航栏HTML
    createNavBar() {
        const user = this.getUser();
        return `
            <nav style="background: #f8f9fa; padding: 15px; margin-bottom: 20px; border-radius: 5px;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <button onclick="AUTH.redirectWithToken('http://${window.location.hostname}:30081')" 
                                style="margin-right: 10px; padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">
                            用户中心
                        </button>
                        <button onclick="AUTH.redirectWithToken('http://${window.location.hostname}:30082')" 
                                style="margin-right: 10px; padding: 8px 16px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer;">
                            商品中心
                        </button>
                        <button onclick="AUTH.redirectWithToken('http://${window.location.hostname}:30083')" 
                                style="margin-right: 10px; padding: 8px 16px; background: #17a2b8; color: white; border: none; border-radius: 4px; cursor: pointer;">
                            订单中心
                        </button>
                        <button onclick="window.location.href='http://${window.location.hostname}:30084'" 
                                style="padding: 8px 16px; background: #6c757d; color: white; border: none; border-radius: 4px; cursor: pointer;">
                            系统监控
                        </button>
                    </div>
                    <div>
                        <span style="margin-right: 15px;">欢迎，${user ? user.username : '游客'}</span>
                        <button onclick="AUTH.logout()" 
                                style="padding: 8px 16px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">
                            退出登录
                        </button>
                    </div>
                </div>
            </nav>
        `;
    },
    
    // 退出登录
    logout() {
        if (confirm('确定要退出登录吗？')) {
            this.clearAuth();
            window.location.href = `http://${window.location.hostname}:30081/login.html`;
        }
    },
    
    // 初始化页面（在每个页面的onload中调用）
    initPage(requireAuth = true) {
        // 接收可能的跨服务token
        this.receiveToken();
        
        // 插入导航栏
        const navContainer = document.getElementById('nav-container');
        if (navContainer) {
            navContainer.innerHTML = this.createNavBar();
        }
        
        // 检查认证
        if (requireAuth) {
            return this.checkAuth();
        }
        
        return true;
    }
};

// 如果是Node.js环境，导出模块
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AUTH;
}
EOF

echo "auth.js已修复！"