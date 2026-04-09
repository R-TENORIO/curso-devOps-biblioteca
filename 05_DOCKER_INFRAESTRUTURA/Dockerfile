# ============================================================
# Dockerfile - Sistema de Biblioteca Universitária Digital
# Projeto Integrado DevOps - Anhanguera 2026
# Autor: Rodrigo Tenorio Cavalcanti da Silva
# ============================================================

FROM php:8.2-apache

LABEL maintainer="Rodrigo Tenorio Cavalcanti da Silva"
LABEL description="Sistema de Biblioteca Universitária - Apache/PHP/MySQL"
LABEL version="1.0.0"

# Instalar dependências
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Instalar extensões PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mysqli \
        pdo \
        pdo_mysql \
        gd \
        zip

# Habilitar mod_rewrite
RUN a2enmod rewrite headers

# Configurar Apache
RUN echo '<Directory /var/www/html>\n\
    Options Indexes FollowSymLinks\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>' > /etc/apache2/conf-available/custom.conf \
    && a2enconf custom

# Timezone
RUN echo "date.timezone=America/Sao_Paulo" > /usr/local/etc/php/conf.d/timezone.ini

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health_check.php || exit 1

EXPOSE 80
CMD ["apache2-foreground"]
